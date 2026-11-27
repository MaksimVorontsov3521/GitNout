-- dummy source for the TRIBUS capability test: the sheet is generated from the .bdf symbol,
-- this file only has to exist so the project's VHDL_FILE assignment resolves.
library ieee;
use ieee.std_logic_1164.all;

entity REGV is
  port (D : in  std_logic_vector(1 downto 0);
        CLK : in std_logic;
        OE : in std_logic;
        Q : out std_logic_vector(1 downto 0);
        R : out std_logic_vector(3 downto 0);
        S : out std_logic_vector(1 downto 0));
end REGV;

architecture behav of REGV is
begin
  Q <= (others => 'Z') when OE = '0' else D;
  R <= (others => '0');
  S <= (others => '0');
end behav;
