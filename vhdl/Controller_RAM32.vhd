LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY Controller_RAM32 IS
    PORT
    (
      clk       : in std_logic;
      rst       : in std_logic;
      wr_en     : in std_logic;
      wr_ack    : out std_logic;
      wr_data   : in std_logic_vector(31 downto 0);

      rd_en     : in std_logic;
      rd_data   : out std_logic_vector(31 downto 0)
    );
END Controller_RAM32;


ARCHITECTURE Controller_RAM32_arh OF Controller_RAM32 IS

component RAM32 IS
	PORT
	(
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		wraddress		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
	);
end component RAM32;

    signal raddr    : std_logic_vector(3 downto 0):=(others => '0');
    signal waddr    : std_logic_vector(3 downto 0):=(others => '0');
    signal addr     : std_logic:= '0';
    signal addr_n   : std_logic;
    signal next_addr: std_logic;

begin
next_addr_proc :
  process(clk)
  begin
    if rising_edge(clk) then
      if (rst = '1') then
        next_addr <= addr;
        wr_ack <= '0';
      elsif ((next_addr = addr) and (wr_en = '1')) then
        next_addr <= not addr;
      end if;
    end if;
  end process;

addr_gen_proc :
  process(clk)
  begin
    if rising_edge(clk) then
      if (rst = '1') then
        addr <= '0';
      elsif (rd_en = '1') then
        addr <= (next_addr);
      end if;
    end if;
  end process;

  addr_n <= (not addr);
  waddr(0) <= addr;
  raddr(0) <= addr_n;

RAM32_inst : RAM32 
    port map
    (
        clock       => clk,
        data        => wr_data,
        rdaddress   => raddr,
        wraddress   => waddr,
        wren        => wr_en,
        q           => rd_data
    );

end Controller_RAM32_arh;