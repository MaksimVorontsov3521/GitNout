library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity encoder64_6 is
    Port ( 
        r  : in  STD_LOGIC_VECTOR(63 downto 0); 
        ei : in  STD_LOGIC;                     
        a  : out STD_LOGIC_VECTOR(5 downto 0);  
        g  : out STD_LOGIC;                     
        eo : out STD_LOGIC                     
    );
end encoder64_6;

architecture behavioral of encoder64_6 is
begin
    process(r, ei)
        variable found : boolean; 
    begin
       
        a  <= "000000";
        g  <= '0';
        eo <= '0';
        found := false;

        if ei = '1' then
            
            for i in 63 downto 0 loop
               
                if not found and r(i) = '1' then
                    a <= std_logic_vector(to_unsigned(i, 6));
                    g <= '1';
                    found := true;
                end if;
            end loop;
            
            if not found then
                eo <= '1';
            end if;
        end if;
    end process;
end behavioral;