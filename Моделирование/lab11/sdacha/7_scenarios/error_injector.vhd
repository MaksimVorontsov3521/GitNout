--------------------------------------------------------------------------
-- Work 11 : ERROR INJECTOR  (the noisy channel of the structural model)
-- Quartus II 5.0 (build 148), VHDL-93, ieee.std_logic_1164 only.
--
--   DATA_OUT <= DATA_IN xor ERROR_MASK
--
-- Both vectors are (7 downto 0), so the XOR is element by element:
-- DATA_OUT(7) is position 1 of the codeword ... DATA_OUT(0) is position 8.
-- A '1' in ERROR_MASK flips exactly that bit of the codeword, '0' keeps it.
-- The N-bit XOR of STD_LOGIC_VECTOR is defined in IEEE Std 1164-1993, so no
-- std_logic_unsigned / numeric_std is needed here.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity error_injector is
  port ( DATA_IN, ERROR_MASK : in  std_logic_vector(7 downto 0);
         DATA_OUT            : out std_logic_vector(7 downto 0) );
end error_injector;

architecture behavioral of error_injector is
begin
  DATA_OUT <= DATA_IN xor ERROR_MASK;
end behavioral;
