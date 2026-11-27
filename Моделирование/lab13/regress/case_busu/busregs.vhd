-- Stand-in sources for the TRIBUS capability test. The host build only stages these files
-- into the project (VHDL_FILE assignment); the sheets are generated from the .bsf symbol.
library ieee;
use ieee.std_logic_1164.all;

entity RB is
  port (A : in std_logic; CLK : in std_logic; OE : in std_logic; Q : out std_logic_vector(1 downto 0));
end RB;
architecture behav of RB is begin
  Q <= (others => 'Z') when OE = '0' else (others => A);
end behav;

entity RB4 is
  port (A : in std_logic; CLK : in std_logic; OE : in std_logic; R : out std_logic_vector(3 downto 0));
end RB4;
architecture behav of RB4 is begin
  R <= (others => 'Z') when OE = '0' else (others => A);
end behav;

entity SB is
  port (D : in std_logic_vector(1 downto 0); Z : out std_logic);
end SB;
architecture behav of SB is begin
  Z <= D(0) or D(1);
end behav;

entity SB4 is
  port (E : in std_logic_vector(3 downto 0); Z : out std_logic);
end SB4;
architecture behav of SB4 is begin
  Z <= E(0);
end behav;

entity RB2 is
  port (A : in std_logic; CLK : in std_logic; OE : in std_logic; S : out std_logic_vector(1 downto 0));
end RB2;
architecture behav of RB2 is begin
  S <= (others => 'Z') when OE = '0' else (others => A);
end behav;
