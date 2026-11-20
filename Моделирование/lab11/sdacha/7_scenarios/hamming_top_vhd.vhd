--------------------------------------------------------------------------
-- Work 11 : STRUCTURAL top model  encoder -> channel with errors -> decoder
-- Quartus II 5.0 (build 148), VHDL-93, ieee.std_logic_1164 only.
--
-- Entities used (each one file, one entity, one architecture):
--   encoder.vhd, error_injector.vhd, decoder.vhd
--
-- Codeword on the channel:  CW = K1 & K2 & D0 & K3 & D1 & D2 & D3 & K
-- i.e. CW(7)=K1 (position 1) ... CW(0)=K (position 8).
-- CW is an internal signal; the OUT port CODE is only connected to it,
-- never read (Quartus II 5.0 rule for ports of mode OUT).
--
-- ERROR_MASK(7) flips position 1 ... ERROR_MASK(0) flips position 8.
--------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity hamming_top_vhd is
  port ( D0, D1, D2, D3 : in  std_logic;                    -- information data
         ERROR_MASK     : in  std_logic_vector(7 downto 0); -- channel errors
         CODE           : out std_logic_vector(7 downto 0); -- codeword before errors
         RX             : out std_logic_vector(7 downto 0); -- codeword after the channel
         OUT_DATA       : out std_logic_vector(3 downto 0); -- decoded data
         ONE_ERR        : out std_logic;
         DBL_ERR        : out std_logic );
end hamming_top_vhd;

architecture structural of hamming_top_vhd is

  component encoder is
    port ( D0, D1, D2, D3 : in  std_logic;
           K1, K2, K3, K  : out std_logic );
  end component;

  component error_injector is
    port ( DATA_IN, ERROR_MASK : in  std_logic_vector(7 downto 0);
           DATA_OUT            : out std_logic_vector(7 downto 0) );
  end component;

  component decoder is                      -- IN_DATA: IN is reserved in VHDL-93
    port ( IN_DATA  : in  std_logic_vector(7 downto 0);
           OUT_DATA : out std_logic_vector(3 downto 0);
           ONE_ERR  : out std_logic;
           DBL_ERR  : out std_logic );
  end component;

  signal SK1, SK2, SK3, SK : std_logic;             -- check bits from the encoder
  signal CW                : std_logic_vector(7 downto 0);  -- codeword, before channel
  signal RW                : std_logic_vector(7 downto 0);  -- codeword, after channel

begin
  U1 : encoder port map ( D0, D1, D2, D3, SK1, SK2, SK3, SK );

  CW <= SK1 & SK2 & D0 & SK3 & D1 & D2 & D3 & SK;
  CODE <= CW;

  U2 : error_injector port map ( CW, ERROR_MASK, RW );

  RX <= RW;                      -- the corrupted word, for observation

  U3 : decoder port map ( RW, OUT_DATA, ONE_ERR, DBL_ERR );

end structural;
