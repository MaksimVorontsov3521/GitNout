library IEEE;
use IEEE.std_logic_1164.all;

entity mem4 is
    port (
        X1, X2, X3, X4 : in  std_logic;
        write          : in  std_logic;
        Reset          : in  std_logic;
        Read           : in  std_logic;
        Q1, Q2, Q3, Q4 : out std_logic
    );
end mem4;

architecture beh of mem4 is
    signal reg1, reg2, reg3, reg4 : std_logic;
begin
    process (write, Reset)
    begin
        if Reset = '0' then
            reg1 <= '0';
            reg2 <= '0';
            reg3 <= '0';
            reg4 <= '0';
        elsif rising_edge(write) then
            reg1 <= X1;
            reg2 <= X2;
            reg3 <= X3;
            reg4 <= X4;
        end if;
    end process;
    Q1 <= reg1 and Read;
    Q2 <= reg2 and Read;
    Q3 <= reg3 and Read;
    Q4 <= reg4 and Read;
end beh;