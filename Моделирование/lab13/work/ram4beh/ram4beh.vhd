------------------------------------------------------------------------------
--  Lab 13, task 2: behavioural VHDL model of the simplest 4-bit memory of
--  figure 18.7 (chapter 18, "Schemes pamyati").
--
--  Task 1 realises the same circuit structurally from primitives on a schematic
--  sheet: two invertors and eight AND gates turn the 2-bit address and the write
--  enable into four cell strobes, four D-type flip-flops with an enable (the DV
--  trigger of section 18.3.1: terminals D, CLK, ENA and the active-low
--  asynchronous PRN / CLRN) store the four bits, and four tri-state buffers tie
--  the cell outputs to one shared Q.
--
--  This model states the SAME contract with no gates at all, so that the two
--  descriptions can be confronted by measurement on identical stimulus. The
--  points the chapter leaves for the student to work out ("predlagaeem
--  samostoyatelno razobrat'sya, kak v ZU zapisyvaetsya i schityvaetsya
--  informatsiya") are made explicit here:
--
--    * we = '1' selects WRITE mode and we = '0' selects READ mode - one control
--      line does both jobs, because a cell may only be driven onto the shared
--      output when it is certainly not being written;
--    * a write is taken on the RISING edge of the common clock, and only by the
--      one cell whose address matches;
--    * a read is combinational: the addressed cell drives Q, and while we = '1'
--      the output buffer is disabled so Q floats to 'Z';
--    * PRN and CLRN are held inactive (section 18.3.1 notes that a floating
--      terminal of this trigger carries a 1), so the model neither presets nor
--      clears, and every test writes a cell before it reads it back - no
--      expectation therefore depends on the power-up state of a flip-flop.
--
--  Capacity note required by the task text: this memory holds 4 BITS, i.e. four
--  cells of one bit each, so the information signal D has only two possible
--  values. "Four different values of the information signal stored in different
--  cells" is realised as four write events carrying 1, 0, 1, 0 into four
--  different addresses - the largest distinct pattern a 1-bit data port can
--  express - and the read-back then shows each cell kept its own value.
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity ram4beh is
  port ( clk : in  std_logic;                     -- common clock of the four triggers
         we  : in  std_logic;                     -- '1' = write, '0' = read
         a   : in  std_logic_vector(1 downto 0);  -- address: a(0) = A0, a(1) = A1
         d   : in  std_logic;                     -- the information bit
         q   : out std_logic );                   -- shared tri-stated output
end entity ram4beh;

architecture behaviour of ram4beh is
  type cell_array is array (0 to 3) of std_logic;
  signal cell : cell_array := (others => '0');    -- the four storing elements
  signal sel_bit : std_logic;                      -- output of the read multiplexer
begin

  -- ---- write side: one clocked process, the address choosing which cell takes d
  process (clk)
  begin
    if rising_edge(clk) then
      if we = '1' then
        if    a = "00" then cell(0) <= d;
        elsif a = "01" then cell(1) <= d;
        elsif a = "10" then cell(2) <= d;
        elsif a = "11" then cell(3) <= d;
        end if;
      end if;
    end if;
  end process;

  -- ---- read side: address multiplexer, then the tri-state output buffer that the
  --      structural sheet builds from four TRI primitives.
  sel_bit <= cell(0) when a = "00" else
             cell(1) when a = "01" else
             cell(2) when a = "10" else
             cell(3) when a = "11" else '0';

  q <= sel_bit when we = '0' else 'Z';

end architecture behaviour;
