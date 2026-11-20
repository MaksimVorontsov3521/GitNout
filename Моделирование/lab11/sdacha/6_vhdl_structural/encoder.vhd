--------------------------------------------------------------------------
-- Work 11 : ENCODER of the modified Hamming (8,4) code
-- Quartus II 5.0 (build 148), VHDL-93, ieee.std_logic_1164 only.
--
-- Equations verbatim from the manual (plan 16.1.1):
--   K1 = D0 xor D1 xor D3
--   K2 = D0 xor D2 xor D3
--   K3 = D1 xor D2 xor D3
--   K  = K1 xor K2 xor D0 xor K3 xor D1 xor D2 xor D3
--
-- Quartus II 5.0 restriction honoured here: a port of mode OUT must not be
-- read inside an expression. The formula of K uses K1/K2/K3, so the three
-- sums are first built on internal signals SK1/SK2/SK3 and only then fed to
-- the OUT ports. The logic is identical to the manual, no term is changed.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity encoder is
  port ( D0, D1, D2, D3 : in  std_logic;                -- information bits
         K1, K2, K3, K  : out std_logic );               -- check bits
end encoder;

architecture behavioral of encoder is
  signal SK1, SK2, SK3 : std_logic;                      -- internal copies of K1..K3
begin
  SK1 <= D0 xor D1 xor D3;
  SK2 <= D0 xor D2 xor D3;
  SK3 <= D1 xor D2 xor D3;

  K1 <= SK1;
  K2 <= SK2;
  K3 <= SK3;
  K  <= SK1 xor SK2 xor D0 xor SK3 xor D1 xor D2 xor D3;
end behavioral;
