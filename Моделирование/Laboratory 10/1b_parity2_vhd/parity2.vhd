library ieee;
use ieee.std_logic_1164.all;

entity parity2 is
    port (
        x0  : in  std_logic;
        x1  : in  std_logic;
        c   : in  std_logic;
        Ech : out std_logic;
        En  : out std_logic
    );
end parity2;

architecture behavioral of parity2 is
    signal t       : std_logic;
    signal ech_sig : std_logic;
begin
    t       <= x0 xor x1;
    ech_sig <= t xor c;
    Ech     <= ech_sig;
    En      <= not ech_sig;
end behavioral;
