--------------------------------------------------------
-- FPGA_EDC top level test bench
--
--------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY testbench IS
END testbench;

ARCHITECTURE behavior OF testbench IS 
    -- Component Declaration
    component mojo_top is
    Port ( 
        clk50m              : in    STD_LOGIC;
        rst_n               : in    STD_LOGIC;
        cclk                : in    STD_LOGIC; -- spi/fpga programming clock (not used).
        led                 : out   STD_LOGIC_VECTOR (7 downto 0); -- board LEDs

        -- RS232
        serial_tx           : out   STD_LOGIC;  -- pin 7 on SV2
        serial_rx           : in    STD_LOGIC;  -- pin 5 on SV2

        -- SPI1 signals
        spi1_miso           : in    STD_LOGIC;    -- pin 11 on SV2
        spi1_mosi           : out   STD_LOGIC;    -- pin 13 on SV2
        spi1_sclk           : out   STD_LOGIC;    -- pin 9 on SV2
        spi1_cs_n           : out   STD_LOGIC_VECTOR( 3 downto 0)  -- pins 10,12,14,16 on SV2

    );
    end component mojo_top;

    -- signals
    signal clk50m           : std_logic;
    signal rst_n            : std_logic;
    signal serial_tx        : std_logic;
    signal serial_rx        : std_logic;
    signal spi1_miso        : std_logic;
    signal spi1_mosi        : std_logic;
    signal spi1_sclk        : std_logic;
    signal spi1_cs_n        : std_logic_vector( 3 downto 0);

    constant tx_bit_period  : time := 8.680555 us;
    signal serial_ce        : std_logic;  -- clock enable for serial generation procedure
    

    -- procedure to send a byte of data as a rs232 serial stream
    procedure serial_send (
            constant input_byte          : in std_logic_vector(7 downto 0);
            signal tx_out                : out std_logic
        ) is
    begin
        tx_out <= '1'; -- idle state;
        wait until rising_edge( serial_ce );
        tx_out <= '0'; -- tx start bit.
        wait until rising_edge( serial_ce );
        tx_out <= input_byte(0);
        wait until rising_edge( serial_ce );
        tx_out <= input_byte(1);
        wait until rising_edge( serial_ce );
        tx_out <= input_byte(2);
        wait until rising_edge( serial_ce );
        tx_out <= input_byte(3);
        wait until rising_edge( serial_ce );
        tx_out <= input_byte(4);
        wait until rising_edge( serial_ce );
        tx_out <= input_byte(5);
        wait until rising_edge( serial_ce );
        tx_out <= input_byte(6);
        wait until rising_edge( serial_ce );
        tx_out <= input_byte(7);
        wait until rising_edge( serial_ce );
        tx_out <= '0'; -- stop bit
        wait until rising_edge( serial_ce );
        tx_out <= '1'; -- back to idle
        wait until rising_edge( serial_ce );
        wait until rising_edge( serial_ce );
        wait until rising_edge( serial_ce );
        wait until rising_edge( serial_ce );
        wait until rising_edge( serial_ce );
        wait until rising_edge( serial_ce );

    end procedure;
                    

BEGIN

    serial_ce_gen : process
    begin
        serial_ce <= '0';
        wait for tx_bit_period/2;
        serial_ce <= '1';
        wait for tx_bit_period/2;
    end process;

    -- clock and reset generation
    clk50_gen : process
    begin
        clk50m <= '0';
        wait for 10 ns;  -- 1/2 50 MHz clock period
        clk50m <= '1';
        wait for 10 ns;  -- 1/2 50 MHz clock period
    end process;

    -- Component Instantiation
    mojo_unit : mojo_top
        port map (
            clk50m          => clk50m,
            rst_n           => rst_n,
            cclk            => '1',
            serial_tx       => serial_tx,
            serial_rx       => serial_rx,
            spi1_miso       => spi1_miso,
            spi1_mosi       => spi1_mosi,
            spi1_sclk       => spi1_sclk,
            spi1_cs_n       => spi1_cs_n
        );

    tb_stim : process
    begin
        rst_n <= '0';     -- reset active
        wait for 80 ns;   -- wait for 4 clock cycles
        rst_n <= '1';     -- reset de-asserted..
        wait for 80 ns;   -- wait for 4 clock cycles
        
        -- turn LEDs on ( address 0x03 )
        serial_send( x"03", serial_rx );
        serial_send( x"55", serial_rx );

        serial_send( x"03", serial_rx );
        serial_send( x"AA", serial_rx );

        -- read back value from led register
        serial_send( x"83", serial_rx );


        -- send a write to address 2 ( spi1_baud_reg )
        -- cmd format (R/!W <7 bits of address> )
        serial_send( x"02", serial_rx );  -- address 2 as a write
        serial_send( x"19", serial_rx );  -- set spi baud register to 25 -> 500 KHz spi clock
        
        -- now issue a serial read of the buad register (addr 02)
        serial_send( x"82", serial_rx );
        wait for tx_bit_period*10;  -- should get a byte back from the data bus on the uart..     
    
        wait for 1 us;
        rst_n <= '0'; -- assert reset
        wait;  -- stop simulation

    end process;
         

END ARCHITECTURE;
