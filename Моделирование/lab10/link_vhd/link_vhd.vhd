library ieee;
use ieee.std_logic_1164.all;

entity link_vhd is
    port (
        X     : in  std_logic_vector(7 downto 0);
        ERR   : in  std_logic_vector(8 downto 0);
        Outp  : out std_logic_vector(7 downto 0);
        ERROR : out std_logic;
        OK    : out std_logic
    );
end link_vhd;

architecture structural of link_vhd is
    signal P    : std_logic;
    signal W, R : std_logic_vector(8 downto 0);
begin
    tx : entity work.eo8
        port map (X => '0' & X, EVEN => P, ODD => open);

    W <= P & X;

    ch : entity work.dtm
        port map (W => W, ERR => ERR, Y => R);

    rx : entity work.eo8
        port map (X => R, EVEN => ERROR, ODD => OK);

    Outp <= R(7 downto 0);
end structural;
