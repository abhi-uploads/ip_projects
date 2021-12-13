

Library ieee;
Use ieee.std_logic_1164.ALL;
Use ieee.std_logic_unsigned.ALL;
Use ieee.numeric_std.ALL;

entity spi_master_TB is
    
end spi_master_TB;

architecture spi_master_TB_arch of spi_master_TB is

component spi_master   
       generic
          ( 
             freq_div          : integer range 1 to 256  
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
end component;
           
           Type mode is (read,write,halt); 
           signal s_mode : mode;
           Type test_case is (reset,t0,t1,t2,t3,t4,t5,t6);
           signal s_test_case : test_case;
           signal s_freq_div : integer := 0; 
           signal test_count           :   integer := 0; 
           signal stop           :   std_logic ;  
           
           signal s_rst_n           :   std_logic ;                          
           signal s_clk_apb         :   std_logic := '0';                    
           signal s_apb_pwrite      :   std_logic;                    
           signal s_apb_psel        :   std_logic;                    
           signal s_apb_penable     :   std_logic;                    
           signal s_apb_paddr       :   std_logic_vector(7  downto 0);
           signal s_apb_pwdata      :   std_logic_vector(15 downto 0);
           signal s_apb_prdata      :   std_logic_vector(15 downto 0);
           signal s_apb_strb        :   std_logic_vector(1  downto 0);
           signal s_interrupt       :   std_logic;                    
           signal write_reg         :   std_logic;
           signal read_reg          :   std_logic;                                                         
           signal s_miso            :   std_logic;                    
           signal s_mosi            :   std_logic;                    
           signal s_sclk            :   std_logic;                    
           signal s_cs_n            :   std_logic_vector(3  downto 0); 
               
begin

    s_clk_apb <= not(s_clk_apb) after 50 ns;
    

    u0_spi_master : spi_master
    generic map(   
        freq_div    =>  8       
        )
    port map (
    
        rst_n       =>  s_rst_n         ,      
        clk_apb     =>  s_clk_apb       ,
        apb_pwrite  =>  s_apb_pwrite    ,
        apb_psel    =>  s_apb_psel      ,
        apb_penable =>  s_apb_penable   ,
        apb_paddr   =>  s_apb_paddr     ,
        apb_pwdata  =>  s_apb_pwdata    ,
        apb_prdata  =>  s_apb_prdata    ,
        apb_strb    =>  s_apb_strb      ,
        interrupt   =>  s_interrupt     ,
                                   
        miso        =>  s_miso          ,
        mosi        =>  s_mosi          ,
        sclk        =>  s_sclk          ,
        cs_n        =>  s_cs_n              
        
        );
        
        reset_process: process
        begin
                s_rst_n <= '0';
                wait for 500 ns; 
                s_rst_n <= '1';
                wait;
        end process;
                            
        PROCESS(s_rst_n,s_clk_apb) 
        BEGIN             
                      
                  IF s_rst_n = '0' THEN
                     s_mode <= halt;
                  ELSE IF (s_clk_apb'EVENT AND s_clk_apb = '1' AND s_rst_n = '1') THEN
                     --s_test_case    <= t0;   
                     CASE s_test_case IS
                        when reset  =>  s_mode  <= halt;
                                        if(test_count =0) then
                                            s_test_case <= t0;
                                            s_mode  <= write;
                                        else if(test_count = 1)  then   
                                            s_test_case <= t1;
                                        end if;
                                        end if;              
                        ---Test case for transferring 8 bit data
                        when t0     =>  if (test_count =0 and stop /= '1' ) then 
                                            s_mode          <= write;
                                            s_apb_paddr     <= x"04";       --address of control reg
                                            s_apb_pwdata    <= x"00FF";     --data for control reg
                                            s_miso          <= '1'; 
                                            write_reg       <= '1';
                                        end if;
                                        if (write_reg ='1' and stop /= '1') then  
                                            s_mode          <= halt;
                                            s_apb_paddr     <= x"08";       --address of transmit data reg
                                            s_apb_pwdata    <= x"12BA";     --data for transmit data reg  
                                            s_apb_strb      <= "01";
                                            write_reg       <= '0';
                                            stop            <= '1';
                                        end if;
                                        if(s_interrupt = '1') then
                                            test_count      <= test_count  +   1;
                                            s_mode          <= read;
                                            s_apb_paddr     <= x"00";   --address of status reg                                           
                                            s_test_case     <= reset;
                                        end if;
                                        
                        when others  =>  s_test_case     <= reset;               
                     END CASE;
                     CASE s_mode IS
    
                        WHEN read =>    s_apb_psel      <= '1';
                                        s_apb_pwrite    <= '0';
                                        s_apb_penable   <= '1';                                         
                                        s_mode          <= halt;
                           
                        WHEN write=>    s_apb_psel      <= '1';
                                        s_apb_pwrite    <= '1';
                                        s_apb_penable   <= '1';                                         
                                        --s_mode          <= halt;
                           
                        WHEN halt =>    --s_rst_n         <= '0';
                                        --s_clk_apb       <= '0';
                                        s_apb_pwrite    <= '0';
                                        s_apb_psel      <= '0';
                                        s_apb_penable   <= '0';
                                        s_apb_paddr     <= x"00";
                                        s_apb_pwdata    <= x"0000";
                                        s_apb_prdata    <= x"0000";
                                        --s_apb_strb      <= "00";
                                        s_interrupt     <= '0';                                                   
                                        --s_miso          <= '0';
                                        --s_mosi          <= '0';
                                        --s_sclk          <= '0';
                                        --s_cs_n          <= x"0";                           
                     END CASE;

                  END IF;   
                  END IF;
        END PROCESS;
     
          
end spi_master_TB_arch;
