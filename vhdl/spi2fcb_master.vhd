-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
-- need conversion function to convert reals/integers to std logic vectors
use ieee.std_logic_arith.conv_std_logic_vector;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


package proc_common_pkg is
-------------------------------------------------------------------------------
-- Function and Procedure Declarations
-------------------------------------------------------------------------------
function clog2(x : positive) return natural;
function log2(x : natural) return integer;
end proc_common_pkg;

package body proc_common_pkg is
--------------------------------------------------------------------------------
-- Function clog2 - returns the integer ceiling of the base 2 logarithm of x,
--                  i.e., the least integer greater than or equal to log2(x).
--------------------------------------------------------------------------------
function clog2(x : positive) return natural is
  variable r  : natural := 0;
  variable rp : natural := 1; -- rp tracks the value 2**r
begin 
  while rp < x loop -- Termination condition T: x <= 2**r
    -- Loop invariant L: 2**(r-1) < x
    r := r + 1;
    if rp > integer'high - rp then exit; end if;  -- If doubling rp overflows
      -- the integer range, the doubled value would exceed x, so safe to exit.
    rp := rp + rp;
  end loop;
  -- L and T  <->  2**(r-1) < x <= 2**r  <->  (r-1) < log2(x) <= r
  return r; --
end clog2;

-------------------------------------------------------------------------------
-- Function log2 -- returns number of bits needed to encode x choices
--   x = 0  returns 0
--   x = 1  returns 0
--   x = 2  returns 1
--   x = 4  returns 2, etc.
-------------------------------------------------------------------------------
--
function log2(x : natural) return integer is
  variable i  : integer := 0; 
  variable val: integer := 1;
begin 
  if x = 0 then return 0;
  else
    for j in 0 to 29 loop -- for loop for XST 
      if val >= x then null; 
      else
        i := i+1;
        val := val*2;
      end if;
    end loop;
  -- Fix per CR520627  XST was ignoring this anyway and printing a  
  -- Warning in SRP file. This will get rid of the warning and not
  -- impact simulation.  
  -- synthesis translate_off
    assert val >= x
      report "Function log2 received argument larger" &
             " than its capability of 2^30. "
      severity failure;
  -- synthesis translate_on
    return i;
  end if;  
end function log2; 

end package body proc_common_pkg;



LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

library altera; 
use altera.altera_primitives_components.all;
library work;
use work.proc_common_pkg.log2;

ENTITY spi2fcb_master IS
    generic( 
        c_cpol              : integer := 1;  --spi clock polarity mode
        c_cpha              : integer := 1;  --spi clock phase mode
        c_spi_data_width    : integer := 8;
        c_lsb_first         : integer := 1;
        c_m_fcb_addr_width  : integer := 8;
        c_m_fcb_data_width  : integer := 32
    );
    port(
        -- spi interface
        SCK         : in std_logic;
        CS          : in std_logic;
        MOSI        : in std_logic;
        MISO        : inout std_logic;
        -- master fcb interface
        m_fcb_clk   : in std_logic;
        m_fcb_resetn: in std_logic;
        m_fcb_addr  : out std_logic_vector(c_m_fcb_addr_width - 1 downto 0);
        m_fcb_wrdata: out std_logic_vector(c_m_fcb_data_width - 1 downto 0);
        m_fcb_wrreq : out std_logic;
        m_fcb_wrack : in std_logic;
        m_fcb_rddata: in std_logic_vector(c_m_fcb_data_width - 1 downto 0);
        m_fcb_rdreq : out std_logic;
        m_fcb_rdack : in std_logic
    );

END spi2fcb_master;

ARCHITECTURE spi_master_arh OF spi2fcb_master IS
    type spi_st is (idle, spi_wr_adress, spi_addr_decod, spi_wr_data, spi_rd_data, m_fcb_wr);
    signal spi_state, spi_next_state : spi_st;
    signal addr_bit_counter : std_logic_vector(log2(c_m_fcb_addr_width) downto 0);
    signal data_bit_counter : std_logic_vector(log2(c_m_fcb_data_width) downto 0);
    signal address  : std_logic_vector(c_m_fcb_addr_width-1 downto 0);
    signal data     : std_logic_vector(c_m_fcb_data_width-1 downto 0);
    signal fcb_rd_data : std_logic_vector(c_m_fcb_data_width-1 downto 0);
    signal fsm_addr_ph  : std_logic;
    signal fsm_data_ph  : std_logic;
    signal fsm_rd_data_ph: std_logic;
    signal sck_edge : std_logic;
    signal sck_fall : std_logic;
    signal sck_d    : std_logic;
    signal wr_req   : std_logic;
    signal rd_req   : std_logic;
begin 

m_fcb_wrdata <= data;
m_fcb_addr <= address;

sck_delay_proc:
    process(m_fcb_clk)
    begin
      if rising_edge(m_fcb_clk) then
        if (m_fcb_resetn = '0') then
          sck_d <= '0';
        else 
          sck_d <= SCK;
        end if;
      end if;
    end process;

sck_rising_edge_generate : if ((c_cpol = 0) and (c_cpha = 0)) or ((c_cpol = 1) and (c_cpha = 1)) generate
    sck_edge <= (not sck_d) and SCK;
    sck_fall <= sck_d and (not SCK);
end generate sck_rising_edge_generate;

sck_falling_edge_generate : if ((c_cpol = 1) and (c_cpha = 0)) or ((c_cpol = 0) and (c_cpha = 1)) generate
    sck_edge <= sck_d and (not SCK);
    sck_fall <= (not sck_d) and SCK;
end generate sck_falling_edge_generate;

lsb_addr_bit_first_gen : if (c_lsb_first = 0) generate
addr_bit_counter_proc :
    process(m_fcb_clk)
    begin
      if rising_edge(m_fcb_clk) then
        if (spi_state = idle) then
          addr_bit_counter <= (others => '0');
        elsif (fsm_addr_ph = '1') then
          if (sck_edge = '1') then
            addr_bit_counter <= addr_bit_counter + 1;
            address(c_m_fcb_addr_width-1 downto 1) <= address(c_m_fcb_addr_width-2 downto 0);
            address(0) <= MOSI;
          end if;
        end if;
      end if;
    end process;
end generate lsb_addr_bit_first_gen;

lsb_addr_bit_not_first_gen : if (c_lsb_first = 1) generate
addr_bit_counter_proc :
    process(m_fcb_clk)
    begin
      if rising_edge(m_fcb_clk) then
        if (spi_state = idle) then
          addr_bit_counter <= (others => '0');
        elsif (fsm_addr_ph = '1') then
          if (sck_edge = '1') then
            addr_bit_counter <= addr_bit_counter + 1;
            address(c_m_fcb_addr_width-2 downto 0) <= address(c_m_fcb_addr_width-1 downto 1);
            address(c_m_fcb_addr_width-1) <= MOSI;
          end if;
        end if;
      end if;
    end process;
end generate lsb_addr_bit_not_first_gen;

lsb_data_bit_first_gen : if (c_lsb_first = 0) generate
data_bit_counter_proc :
    process(m_fcb_clk)
    begin
      if rising_edge(m_fcb_clk) then
        if (spi_state = idle) then
          data_bit_counter <= (others => '0');
        elsif (fsm_data_ph = '1') then
          if (sck_edge = '1') then
            data_bit_counter <= data_bit_counter + 1;
            data(c_m_fcb_data_width-1 downto 1) <= data(c_m_fcb_data_width-2 downto 0);
            data(0) <= MOSI;
          end if;
        end if;
      end if;
    end process;
end generate lsb_data_bit_first_gen;

lsb_data_bit_not_first_gen : if (c_lsb_first = 1) generate
data_bit_counter_proc :
    process(m_fcb_clk)
    begin
      if rising_edge(m_fcb_clk) then
        if (spi_state = idle) then
          data_bit_counter <= (others => '0');
        elsif (fsm_data_ph = '1') then
          if (sck_edge = '1') then
            data_bit_counter <= data_bit_counter + 1;
            data(c_m_fcb_data_width-2 downto 0) <= data(c_m_fcb_data_width-1 downto 1);
            data(c_m_fcb_data_width-1) <= MOSI;
          end if;
        end if;
      end if;
    end process;
end generate lsb_data_bit_not_first_gen;

fsm_spi_sync_proc :
    process(m_fcb_clk)
    begin
      if rising_edge(m_fcb_clk) then
        if (m_fcb_resetn = '0') or (CS = '1') then
          spi_state <= idle;
          m_fcb_wrreq <= '0';
        else 
          spi_state <= spi_next_state;
          m_fcb_wrreq <= wr_req;
        end if;
      end if;
    end process;

fsm_spi_output_proc :
    process(spi_state)
    begin
      fsm_addr_ph <= '0';
      fsm_data_ph <= '0';
      fsm_rd_data_ph <= '0';
      wr_req <= '0';
      case spi_state is
        when spi_wr_adress =>
          fsm_addr_ph <= '1';
        when spi_wr_data => 
          fsm_data_ph <= '1';
        when spi_rd_data => 
          fsm_rd_data_ph <= '1';
        when m_fcb_wr =>
          wr_req <= '1';
        when others =>
      end case;
    end process;
fsm_spi_next_state_decode :
    process(spi_state, CS, addr_bit_counter, address(c_m_fcb_addr_width-1), data_bit_counter, m_fcb_wrack)
    begin
      spi_next_state <= spi_state;
        case spi_state is
        when idle =>
          if CS = '0' then
            spi_next_state <= spi_wr_adress;
          end if;
        when spi_wr_adress =>
          if (addr_bit_counter = c_m_fcb_addr_width) then
            spi_next_state <= spi_addr_decod;
          end if;
        when spi_addr_decod =>
          if address(c_m_fcb_addr_width-1) = '0' then 
            spi_next_state <= spi_wr_data;
          else 
            spi_next_state <= spi_rd_data;
          end if;
        when spi_wr_data => 
          if (data_bit_counter = c_m_fcb_data_width) then
            spi_next_state <= m_fcb_wr;
          end if;
        when m_fcb_wr =>
          if (m_fcb_wrack = '1') then
            spi_next_state <= idle;
          else 
            spi_next_state <= m_fcb_wr;
          end if;
        when spi_rd_data => 
          if (data_bit_counter = c_m_fcb_data_width) then
            spi_next_state <= idle;
          end if;
        when others =>
          spi_next_state <= idle;
        end case;
    end process;

lsb_spi_rddata_first_gen : if (c_lsb_first = 1) generate
fcd_rd_data_proc :
    process(m_fcb_clk)
    begin
      if rising_edge(m_fcb_clk) then
        if (m_fcb_resetn = '0') then
          fcb_rd_data <= (others => '0');
        elsif (rd_req = '1') and (m_fcb_rdack = '1') then
          fcb_rd_data <= m_fcb_rddata;
        elsif (sck_fall = '1') then
          fcb_rd_data(c_m_fcb_data_width - 2 downto 0) <= fcb_rd_data(c_m_fcb_data_width - 1 downto 1);
          fcb_rd_data(c_m_fcb_data_width - 1 ) <= '0';
        end if;
      end if;
    end process;

 MISO_TRI: TRI
    port map (a_in => fcb_rd_data(0), oe => fsm_rd_data_ph, a_out => MISO);
end generate lsb_spi_rddata_first_gen;


lsb_spi_rddata_not_first_gen : if (c_lsb_first = 0) generate
fcd_rd_data_proc :
    process(m_fcb_clk)
    begin
      if rising_edge(m_fcb_clk) then
        if (m_fcb_resetn = '0') then
          fcb_rd_data <= (others => '0');
        elsif (rd_req = '1') and (m_fcb_rdack = '1') then
          fcb_rd_data <= m_fcb_rddata;
        elsif (sck_fall = '1') then
          fcb_rd_data(c_m_fcb_data_width - 1 downto 1) <= fcb_rd_data(c_m_fcb_data_width - 2 downto 0);
          fcb_rd_data(0) <= '0';
        end if;
      end if;
    end process;

 MISO_TRI: TRI
    port map (a_in => fcb_rd_data(c_m_fcb_data_width-1), oe => fsm_rd_data_ph, a_out => MISO);
end generate lsb_spi_rddata_not_first_gen;



END spi_master_arh;