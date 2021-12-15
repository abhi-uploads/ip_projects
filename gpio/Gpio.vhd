


Library ieee;
Use ieee.std_logic_1164.ALL;
Use ieee.std_logic_unsigned.ALL;
Use ieee.numeric_std.ALL;

entity gpio is

port(
        rst_n        :  in  std_logic;                                                              
        clk_apb      :  in  std_logic;                            
        apb_pwrite   :  in  std_logic;                            
        apb_psel     :  in  std_logic;                            
        apb_penable  :  in  std_logic;                            
        apb_paddr    :  in  std_logic_vector(16 downto 0);    -- first MSB denotes direction, 1 for in     
        apb_pwdata   :  in  std_logic_vector(15 downto 0);        
        apb_prdata   :  out std_logic_vector(15 downto 0);  
        apb_strb     :  in  std_logic_vector(1  downto 0);      
        interrupt    :  out std_logic;   
               
        gpio_in      :  in  std_logic_vector(15 downto 0);       
        gpio_out     :  out std_logic_vector(15 downto 0);
        gpio_enb      :  out std_logic_vector(15 downto 0)    
             
    );
end gpio;

architecture gpio_arch of gpio is
    
    signal  dir_control_reg : std_logic_vector (15 downto 0);    
    signal  input_sync_1 : std_logic_vector (15 downto 0);
    signal  input_sync_2 : std_logic_vector (15 downto 0);
    signal  input_sync_3 : std_logic_vector (15 downto 0);
          
begin  

process (clk_apb,rst_n,apb_pwrite,apb_psel,apb_penable)
begin

    if (rst_n ='0') then    
        dir_control_reg <= x"0000";
        gpio_out        <= x"0000";
        apb_prdata      <= x"0000";
    else
        input_sync_1    <=  gpio_in;
        input_sync_2    <=  input_sync_1;
        input_sync_3    <=  input_sync_2;
        
        if(clk_apb'event and clk_apb = '1') then
        
            if (apb_pwrite ='1' and apb_psel ='1' and apb_penable ='1') then   
                if(apb_paddr(16) = '1') then
                    dir_control_reg <=  apb_pwdata;       
                    elsif (apb_paddr(16)= '0') then                                                                         
                    GPIO_WRITE : for i in 0 to 15 loop                                    
                                    if(apb_paddr(i) = '1') then                                                                     
                                       gpio_out(i)   <=  apb_pwdata(i);                                                        
                                    end if;
                    end loop;
                    end if;
                end if;
            end if; 
            
            if (apb_pwrite ='0' and apb_psel ='1' and apb_penable ='1') then
                if(apb_paddr(16) = '1') then
                    apb_prdata <=  dir_control_reg;       
                    elsif (apb_paddr(16)= '0') then                                                                         
                        apb_prdata  <= apb_paddr (15 downto 0) and input_sync_3;
                    end if;
                end if;
            end if;                                              

end process; 
        
gpio_enb <= not(dir_control_reg);
            
             
end gpio_arch;                       
                       
   
    
    
    
    
    
