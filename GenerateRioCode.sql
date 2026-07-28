CREATE OR ALTER FUNCTION dbo.GenerateRioCode (
    @OperatorCode VARCHAR(2),   -- OO - OpertorCoe
    @AccountType CHAR(1),       -- Q - Servvice Coe
    @ContractRef VARCHAR(6),    -- RRRRRR
    @PhoneNumber VARCHAR(10)    -- Phone Number
)
RETURNS VARCHAR(12)
AS
BEGIN
    DECLARE @Charset VARCHAR(37) = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ+';
    DECLARE @First9 VARCHAR(9);
    DECLARE @Input VARCHAR(19);
    DECLARE @Char CHAR(1);
    DECLARE @Pos INT;
    DECLARE @C1 INT = 0, @C2 INT = 0, @C3 INT = 0;
    DECLARE @W1 INT = 2, @W2 INT = 3, @W3 INT = 5;
    DECLARE @I INT = 19;

    -- Format & pad inputs
    SET @First9 = UPPER(RIGHT('00' + ISNULL(@OperatorCode, ''), 2)) + 
                  UPPER(ISNULL(@AccountType, '')) + 
                  UPPER(RIGHT('000000' + ISNULL(@ContractRef, ''), 6));
                  
    SET @Input = @First9 + ISNULL(@PhoneNumber, '');

    IF LEN(@Input) <> 19
        RETURN NULL;

    -- Calculate CCC checksum
    WHILE @I >= 1
    BEGIN
        SET @Char = SUBSTRING(@Input, @I, 1);
        -- Case-sensitive character position lookup
        SET @Pos = CHARINDEX(@Char, @Charset COLLATE Latin1_General_CS_AS) - 1;

        IF @Pos < 0
            RETURN NULL;

        SET @C1 = (@C1 + @Pos * @W1) % 37;
        SET @C2 = (@C2 + @Pos * @W2) % 37;
        SET @C3 = (@C3 + @Pos * @W3) % 37;

        SET @W1 = (@W1 * 2) % 37;
        SET @W2 = (@W2 * 3) % 37;
        SET @W3 = (@W3 * 5) % 37;

        SET @I = @I - 1;
    END;

    -- Return 12-char RIO code
    RETURN @First9 + 
           SUBSTRING(@Charset, @C1 + 1, 1) + 
           SUBSTRING(@Charset, @C2 + 1, 1) + 
           SUBSTRING(@Charset, @C3 + 1, 1);
END;
GO