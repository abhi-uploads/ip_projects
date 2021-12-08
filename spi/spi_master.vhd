


Library ieee;
Use ieee.std_logic_1164.ALL;
Use ieee.std_logic_unsigned.ALL;
Use ieee.numeric_std.ALL;

entity spi_master is

generic
   ( 
      freq_div          : integer range 1 to 256  :=  2 
    );
    
port(
    rst_n        :  in  std_logic;                                                              
    clk_apb      :  in  std_logic;                            
    apb_pwrite   :  in  std_logic;                            
    apb_psel     :  in  std_logic;                            
    apb_penable  :  in  std_logic;                            
    apb_paddr    :  in  std_logic_vector(7  downto 0);         
    apb_pwdata   :  in  std_logic_vector(15 downto 0);        
    apb_prdata   :  out std_logic_vector(15 downto 0);  
    apb_strb     :  in  std_logic_vector(1  downto 0);      
    interrupt    :  out std_logic;
                               
    miso         :  in  std_logic;                            
    mosi         :  out std_logic;                            
    sclk         :  out std_logic;                            
    cs_n         :  out std_logic_vector(3  downto 0) 
             
    );
end spi_master;

architecture spi_master_arch of spi_master is

    signal status_reg           : std_logic_vector(15 downto 0);     --  Status Register  
    signal control_reg          : std_logic_vector(15 downto 0);     --  Control Register
    signal txdata_reg           : std_logic_vector(15 downto 0);     --  Transmit Data Register
    signal rxdata_reg           : std_logic_vector(15 downto 0);     --  Receive Data Register  
    signal control_receive      : std_logic := '0';
    signal transmit_data        : std_logic;                         --  
    signal receive_data         : std_logic;
    
    signal spi_start            : std_logic;                         --  
    signal master_mode          : std_logic;                         --  
    signal tx_rx                : std_logic;                         --  
    signal lsb_msb              : std_logic;                         --
    signal intr_en              : std_logic;  
    signal freq_ratio           : std_logic_vector(2 downto 0);      -- 
    
    signal generated_clk        : std_logic;
    signal transfer_start       : std_logic;
    signal status_read          : std_logic;
    signal tx_done              : std_logic := '0';
    signal discard_en           : std_logic := '0';   
    signal discard_reg          : std_logic := '0';   
    signal clock_reg            : std_logic := '0'; 
    signal count_clk            : integer := 0;
    signal count_no             : integer := 0;
    
    signal count_8_tx           : integer :=8;
    signal count_16_tx          : integer :=16;  
    signal count_8_rx           : integer :=8;
    signal count_16_rx          : integer :=16;  
    
       
begin  

------------------------------------ Read process for reading all registers---------------------------------------------------
    read_process: process (rst_n,clk_apb)
    begin  
    
        if (rst_n='0')   then
            status_reg <= (others=>'0');
         else if (apb_penable='1' and apb_psel='1' and apb_pwrite='0'and rst_n='1' and rising_edge(clk_apb) )then        
              ---apb address map
              case apb_paddr (7 downto 0) is 
                    when x"00" =>  apb_prdata   <= status_reg;
                                   status_read  <= '1';
                                   intr_en      <= '0';
                    when x"04" =>  apb_prdata   <= control_reg;
                    when x"08" =>  apb_prdata   <= txdata_reg;
                    when x"0C" =>  apb_prdata   <= rxdata_reg; 
                    when others => apb_prdata   <= (others=>'0');             
              end case;
          end if; 
          end if;                 
    end process;
    
--------------------------------------write process for reading all registers---------------------------------------------------
    write_process: process (rst_n,clk_apb)
    begin   
        if (rst_n='0')   then
            control_reg <= (others=>'0');
            txdata_reg  <= (others=>'0');
            rxdata_reg  <= (others=>'0');
            --mosi        <= '0';          
        end if;
        
            if (apb_penable='1' and apb_psel='1' and apb_pwrite='1' and rst_n='1' and rising_edge(clk_apb) )then        
                 ---------------------------------------apb address map---------------------------------------------------
                 case apb_paddr (7 downto 0) is 
                       when x"04" =>    control_reg     <= apb_pwdata ;
                                        control_receive <= '1';   
                       when x"08" =>    if(tx_done='0') then
                                            txdata_reg      <= apb_pwdata ;
                                            transmit_data   <= '1';
                                            discard_en      <= '1';
                                            tx_done         <= '1';                                          
                                        end if;
                       when x"0C" =>    rxdata_reg      <= apb_pwdata ;
                       when others =>   apb_prdata      <= (others=>'0');              
                 end case;
             end if;
            ---------------------------------------For decoding control register---------------------------------------------------      
            if (control_receive = '1'and rst_n='1' and rising_edge(clk_apb)) then
                     spi_start   <=  control_reg(0);
                     master_mode <=  control_reg(1); 
                     tx_rx       <=  control_reg(2);     
                     lsb_msb     <=  control_reg(3);
                     intr_en     <=  control_reg(4);
                     
                     --freq_ratio  <=  control_reg(6 downto 4);
                     control_receive <= '0'; 
            end if;         
            -----------------------------------------For generating clock---------------------------------------------------         
            if (spi_start = '1' and rst_n='1'and tx_done = '1' ) then
                clock_reg <= '1'; 
                    if (clock_reg <= '0') then
                        generated_clk <='0';
                    end if;                                   
                  if ( rising_edge(clk_apb) and clock_reg = '1') then                                                                                              
                      if (count_no < 16) then
                          count_no    <= count_no   +   1;                                              
                          if (count_clk <= freq_div/2) then              --- for divide by generic specific
                              generated_clk <= not(generated_clk);
                              sclk <= not(generated_clk); 
                              count_clk   <= count_clk  +   1; 
                              if (count_clk = freq_div/2) then
                                    count_clk <= 0;
                              end if;                                                      
                          --else count_clk <= 0;                                                                                                              
                          end if;                                                                                   
                      end if;                                                                       
                      if (count_no =16) then
                          count_no <= 0;
                          generated_clk <= '0';
                          sclk <= '0';
                          clock_reg <= '0';
                          tx_done <= '0';
                          discard_en <= '0';
                      end if;                                                                                                     
                  end if; 
            end if;  
     end process;             
            
----------------------------------------For data transfer---------------------------------------------------
     transreceive_process :process (generated_clk)
     begin
             ------------------------------------------------For MSB transfer first---------------------------------------------------
             if (lsb_msb = '1' and rising_edge(generated_clk) and tx_rx = '1' and  discard_en <= '1') then                             
                     if (apb_strb = x"1" and count_8_tx > 0) then                                                                                            
                         mosi <= txdata_reg(count_8_tx-1);
                         discard_reg <= miso;
                         count_8_tx <= count_8_tx -1;            
                     else if (apb_strb = x"2" and count_16_tx > 8) then      
                         mosi <= txdata_reg(count_16_tx-1);
                         discard_reg <= miso;
                         count_16_tx <= count_16_tx -1; 
                     end if;
                     end if;
             ------------------------------------------------For MSB receive first---------------------------------------------------
             else if (lsb_msb = '1' and rising_edge(generated_clk) and tx_rx = '0' )then
                    if (count_8_tx > 0) then
                        rxdata_reg(count_8_tx-1)  <= miso;
                        rxdata_reg(count_16_tx-1) <= miso;
                        count_8_tx <= count_8_tx -1;
                        count_16_tx <= count_16_tx -1;
                    end if;
             ------------------------------------------------For LSB transfer first---------------------------------------------------
             else if (lsb_msb = '0' and rising_edge(generated_clk) and tx_rx = '1' and  discard_en <= '1' )then  
                    if (apb_strb = x"1" and count_8_tx > 0) then                                                                                            
                        mosi <= txdata_reg(8-count_8_tx);
                        discard_reg <= miso;
                        count_8_tx <= count_8_tx -1;            
                    else if (apb_strb = x"2" and count_16_tx > 8) then      
                        mosi <= txdata_reg(16-count_16_tx);
                        discard_reg <= miso;
                        count_16_tx <= count_16_tx -1;
                    end if;
                    end if;
             ------------------------------------------------For LSB receive first---------------------------------------------------
             else if (lsb_msb = '0' and rising_edge(generated_clk) and tx_rx = '0' )then
                    if (count_8_tx > 0) then
                        rxdata_reg(8-count_8_tx)  <= miso;
                        rxdata_reg(16-count_16_tx) <= miso;
                        count_8_tx <= count_8_tx -1;
                        count_16_tx <= count_16_tx -1;
                    end if;                                 
             else if (count_8_tx = 0 or count_16_tx = 8) then       
                    --clock_reg     <= '0';
                    transmit_data <= '0';
                    --tx_done       <= '0'; 
                    count_8_tx    <=  8 ;
                    count_8_tx    <= 16 ;
                    if (intr_en ='1') then
                        interrupt     <= '1';                        
                    end if;
             end if;
             end if;                    
             end if;
             end if;
             end if;
     end process;
            
             
 end spi_master_arch;                       
                       
   
    
    
    
    
    