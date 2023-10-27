class transaction;  
  bit newd;                 
  rand bit [11:0] din;  // Random 12-bit data input
  bit [11:0] dout;          
  
 // Create a copy of the transaction
  function transaction copy();
    copy = new();             
    copy.newd = this.newd;   
    copy.din  = this.din;     
    copy.dout = this.dout;    
  endfunction
  
endclass

class generator;
  
  transaction tr;           
  mailbox #(transaction) mbx; // Mailbox for transactions
  event done;                 // Done event
  int count = 0;             
  event drvnext;              // Event to synchronize with driver
  event sconext;              // Event to synchronize with scoreboard
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;          
    tr = new();               
  endfunction
  
  task run();
    repeat(count) begin
      assert(tr.randomize) else $error("[GEN] :Randomization Failed");
      mbx.put(tr.copy);       // Put a copy of the transaction in the mailbox
      $display("[GEN] : din : %0d", tr.din);
      @(sconext);             // Wait for the scoreboard synchronization event
    end
    -> done;                  // Signal when done
  endtask
  
endclass
 
class driver;
  
  virtual spi_if vif;      
  transaction tr;             
  mailbox #(transaction) mbx; // Mailbox for transactions
  mailbox #(bit [11:0]) mbxds; // Mailbox for data output to monitor
  event drvnext;              // Event to synchronize with generator
  
  bit [11:0] din;         
 
  function new(mailbox #(bit [11:0]) mbxds, mailbox #(transaction) mbx);
    this.mbx = mbx;          
    this.mbxds = mbxds;
  endfunction
  
  // Set reset signal
  task reset();
    vif.rst <= 1'b1;          
    vif.newd <= 1'b0;         
    vif.din <= 1'b0;          
    repeat(10) @(posedge vif.clk);
    vif.rst <= 1'b0;          
    repeat(5) @(posedge vif.clk);
 
    $display("[DRV] : RESET DONE");
    $display("-----------------------------------------");
  endtask
  
  task run();
    forever begin
      mbx.get(tr);           
      vif.newd <= 1'b1;       // Set new data flag
      vif.din <= tr.din;      
      mbxds.put(tr.din);      // Put data in the mailbox for the monitor
      @(posedge vif.sclk);
      vif.newd <= 1'b0;       // Clear new data flag
      @(posedge vif.done);
      $display("[DRV] : DATA SENT TO DAC : %0d",tr.din);
      @(posedge vif.sclk);
    end
    
  endtask
  
endclass
 
class monitor;
  transaction tr;             
  mailbox #(bit [11:0]) mbx; 
  
  virtual spi_if vif;         
  
  function new(mailbox #(bit [11:0]) mbx);
    this.mbx = mbx;        
  endfunction
  
  task run();
    tr = new();           
    forever begin
      @(posedge vif.sclk);
      @(posedge vif.done);
      tr.dout = vif.dout;     // Record data output
      @(posedge vif.sclk);
      $display("[MON] : DATA SENT : %0d", tr.dout);
      mbx.put(tr.dout);       // Put data in the mailbox
    end  
    
  endtask
  
endclass

class scoreboard;
  mailbox #(bit [11:0]) mbxds, mbxms; // Mailboxes for data from driver and monitor
  bit [11:0] ds;                       // Data from driver
  bit [11:0] ms;                       // Data from monitor
  event sconext;                       // Event to synchronize with environment
  
  function new(mailbox #(bit [11:0]) mbxds, mailbox #(bit [11:0]) mbxms);
    this.mbxds = mbxds;             
    this.mbxms = mbxms;
  endfunction
  
  task run();
    forever begin
      mbxds.get(ds);                   // Get data from driver
      mbxms.get(ms);                   // Get data from monitor
      $display("[SCO] : DRV : %0d MON : %0d", ds, ms);
      
      if(ds == ms)
        $display("[SCO] : DATA MATCHED");
      else
        $display("[SCO] : DATA MISMATCHED");
      
      $display("-----------------------------------------");
      ->sconext;                        // Synchronize with the environment
    end
    
  endtask
  
endclass
 
class environment;
    generator gen;                 
    driver drv;                     
    monitor mon;                   
    scoreboard sco;                
    
    event nextgd;                   // Event for generator to driver communication
    event nextgs;                   // Event for generator to scoreboard communication
  
    mailbox #(transaction) mbxgd;   
    mailbox #(bit [11:0]) mbxds;    
    mailbox #(bit [11:0]) mbxms;    
  
    virtual spi_if vif;             // Virtual interface
  
  function new(virtual spi_if vif);
       
    mbxgd = new();                
    mbxms = new();
    mbxds = new();
    gen = new(mbxgd);             
    drv = new(mbxds,mbxgd);       
    mon = new(mbxms);             
    sco = new(mbxds, mbxms);   
    
    this.vif = vif;
    drv.vif = this.vif;
    mon.vif = this.vif;
    
    gen.sconext = nextgs;     
    sco.sconext = nextgs;
    
    gen.drvnext = nextgd;
    drv.drvnext = nextgd;
  endfunction
  
  task pre_test();
    drv.reset();                    // Perform driver reset
  endtask
  
  task test();
  fork
    gen.run();                      // Run generator
    drv.run();                      // Run driver
    mon.run();                      // Run monitor
    sco.run();                      // Run scoreboard
  join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);       // Wait for generator to finish  
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass
 
module tb;
  spi_if vif();                
  
  top dut(vif.clk,vif.rst,vif.newd,vif.din,vif.dout,vif.done);
  
  initial begin
    vif.clk <= 0;
  end
    
  always #10 vif.clk <= ~vif.clk;
  
  environment env;
  
  assign vif.sclk = dut.m1.sclk;
  
  initial begin
    env = new(vif);
    env.gen.count = 4;
    env.run();
  end
      
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
endmodule
