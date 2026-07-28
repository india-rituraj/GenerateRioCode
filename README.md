# Technical Specification: French Telecom RIO Code Generation & Validation

## Executive Summary

The **RIO** (*Relevé d'Identité Opérateur*) is a standardized 12-character alphanumeric identifier regulated by **ARCEP** (*Autorité de Régulation des Communications Électroniques, des Postes et de la Distribution de la Presse*) in France. It is used in **Mobile Number Portability (MNP)** and **Fixed Number Portability (FNP)** to authenticate customer authorization when transferring telephone numbers between operators.

This document details the mathematical specification, structural decomposition, checksum algorithm, and enterprise multi-language code implementations for generating and validating French RIO codes.

---

## 1. Structural Decomposition

A French RIO code consists of **12 characters** divided into four logical components:

$$\text{Format: } \mathbf{\underbrace{OO}_{\text{Operator ID}} \ \underbrace{Q}_{\text{Account Type}} \ \underbrace{RRRRRR}_{\text{Contract Reference}} \ \underbrace{CCC}_{\text{Control Key / Checksum}}}$$

### Component Overview

| Position | Length | Field Name | Description & Specification |
| :--- | :--- | :--- | :--- |
| **1 – 2** | 2 chars | **Operator ID (`OO`)** | Technical Operator Code assigned by ARCEP/GIE EGP.<br>• `01` = Orange<br>• `02` = SFR<br>• `03` = Bouygues Telecom<br>• `04` = Free Mobile<br>• `10` = NRJ Mobile / Euro-Information Telecom<br>• `60` = Coriolis Telecom<br>• `66` = Lebara Mobile |
| **3** | 1 char | **Account Type (`Q`)** | Quality/Category of subscriber:<br>• `P` = Individual / Particular (*Particulier*)<br>• `E` = Corporate / Business (*Entreprise*)<br>• `F`, `L` = Fixed line / Special service category indicators |
| **4 – 9** | 6 chars | **Contract Ref (`RRRRRR`)** | Unique internal subscriber account or contract identifier (padded with zeros or alphanumeric characters). |
| **10 – 12** | 3 chars | **Control Key (`CCC`)** | Algorithmic checksum computed over the first 9 characters of the RIO plus the subscriber's 10-digit phone number. |

---

## 2. Character Set & Mathematics

### Character Set ($\Sigma$)
The RIO algorithm uses a 37-character alphabet ($\Sigma$) consisting of digits `0-9`, uppercase letters `A-Z`, and the `+` symbol:

$$\Sigma = \{ \text{'0'}, \dots, \text{'9'}, \text{'A'}, \dots, \text{'Z'}, \text{'+'} \}$$

Index mapping for $\Sigma$ (0 to 36):
- Index `0` – `9`: `'0'` to `'9'`
- Index `10` – `35`: `'A'` to `'Z'`
- Index `36`: `'+'`

### Input Vector ($\vec{S}$)
The checksum input $\vec{S}$ is formed by concatenating the first 9 characters of the RIO with the 10-digit national telephone number ($0ZABPQMCDU$):

$$\vec{S} = S[0 \dots 18] = \text{OO} + \text{Q} + \text{RRRRRR} + \text{PHONE\_NUMBER} \quad (|\vec{S}| = 19)$$

### Checksum Formulas ($C_1, C_2, C_3$)

The three control characters ($C_1, C_2, C_3$) are generated using exponential weighted modular sums over $GF(37)$:

$$C_1 = \left( \sum_{i=0}^{18} \text{pos}(S[i]) \cdot 2^{19-i} \right) \bmod 37$$

$$C_2 = \left( \sum_{i=0}^{18} \text{pos}(S[i]) \cdot 3^{19-i} \right) \bmod 37$$

$$C_3 = \left( \sum_{i=0}^{18} \text{pos}(S[i]) \cdot 5^{19-i} \right) \bmod 37$$

Where $\text{pos}(S[i])$ is the 0-based index of character $S[i]$ in $\Sigma$.

The final control key string $\text{CCC}$ is:

$$\text{CCC} = \Sigma[C_1] \mathbin{\Vert} \Sigma[C_2] \mathbin{\Vert} \Sigma[C_3]$$

---

## 3. Reference Software Implementations

### 3.1 JavaScript / TypeScript

```typescript
const RIO_CHARSET: string = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ+";

/**
 * Calculates the 3-character CCC checksum for a French RIO code.
 * @param first9 First 9 characters of the RIO (OOQRRRRRR)
 * @param phone 10-digit French telephone number (0ZABPQMCDU)
 */
export function calculateCCC(first9: string, phone: string): string {
    const cleanFirst9 = first9.toUpperCase().replace(/[^A-Z0-9+]/g, '');
    const cleanPhone = phone.replace(/[^0-9]/g, '');

    if (cleanFirst9.length !== 9 || cleanPhone.length !== 10) {
        throw new Error("Invalid parameters: first9 must be 9 alphanumeric chars, phone must be 10 digits.");
    }

    const inputStr = cleanFirst9 + cleanPhone; // 19 characters
    let c1 = 0, c2 = 0, c3 = 0;

    for (let i = 0; i < inputStr.length; i++) {
        const pos = RIO_CHARSET.indexOf(inputStr[i]);
        if (pos === -1) throw new Error(`Invalid character: ${inputStr[i]}`);
        
        const exp = 19 - i;
        c1 = (c1 + pos * Math.pow(2, exp)) % 37;
        c2 = (c2 + pos * Math.pow(3, exp)) % 37;
        c3 = (c3 + pos * Math.pow(5, exp)) % 37;
    }

    return RIO_CHARSET[c1] + RIO_CHARSET[c2] + RIO_CHARSET[c3];
}

/**
 * Generates a full 12-character RIO code.
 */
export function generateRIO(operatorCode: string, accountType: string, contractRef: string, phone: string): string {
    const oo = operatorCode.padStart(2, '0').substring(0, 2);
    const q = accountType.toUpperCase().substring(0, 1);
    const rrr = contractRef.toUpperCase().padStart(6, '0').substring(0, 6);
    
    const first9 = oo + q + rrr;
    const ccc = calculateCCC(first9, phone);
    
    return first9 + ccc;
}
```

---

### 3.2 Python 3

```python
RIO_CHARSET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ+"

def calculate_ccc(first9: str, phone: str) -> str:
    """Calculates the 3-character CCC checksum for a French RIO code."""
    clean_first9 = "".join(c for c in first9.upper() if c in RIO_CHARSET)
    clean_phone = "".join(filter(str.isdigit, phone))
    
    if len(clean_first9) != 9 or len(clean_phone) != 10:
        raise ValueError("first9 must be 9 characters and phone must be 10 digits.")

    full_input = clean_first9 + clean_phone  # 19 characters
    c1, c2, c3 = 0, 0, 0
    
    for i, char in enumerate(full_input):
        pos = RIO_CHARSET.index(char)
        exp = 19 - i
        c1 = (c1 + pos * (2 ** exp)) % 37
        c2 = (c2 + pos * (3 ** exp)) % 37
        c3 = (c3 + pos * (5 ** exp)) % 37

    return RIO_CHARSET[c1] + RIO_CHARSET[c2] + RIO_CHARSET[c3]

def generate_rio(operator_code: str, account_type: str, contract_ref: str, phone: str) -> str:
    """Generates a complete 12-character RIO code."""
    oo = operator_code.zfill(2)[:2]
    q = account_type.upper()[:1]
    rrr = contract_ref.upper().zfill(6)[:6]
    
    first9 = f"{oo}{q}{rrr}"
    ccc = calculate_ccc(first9, phone)
    return f"{first9}{ccc}"
```

---

## 4. SQL Database Implementations

### 4.1 PostgreSQL (PL/pgSQL)

```sql
CREATE OR REPLACE FUNCTION generate_rio_code(
    p_operator_code VARCHAR(2),   -- OO
    p_account_type CHAR(1),       -- Q ('P' or 'E')
    p_contract_ref VARCHAR(6),    -- RRRRRR
    p_phone_number VARCHAR(10)    -- 10 digits
)
RETURNS VARCHAR(12) AS $$
DECLARE
    v_charset VARCHAR(37) := '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ+';
    v_first9 VARCHAR(9);
    v_input VARCHAR(19);
    v_char CHAR(1);
    v_pos INT;
    v_c1 INT := 0;
    v_c2 INT := 0;
    v_c3 INT := 0;
    v_w1 INT := 2;
    v_w2 INT := 3;
    v_w3 INT := 5;
    i INT;
BEGIN
    v_first9 := UPPER(LPAD(p_operator_code, 2, '0')) || 
                UPPER(p_account_type) || 
                UPPER(LPAD(p_contract_ref, 6, '0'));
                
    v_input := v_first9 || REGEXP_REPLACE(p_phone_number, '[^0-9]', '', 'g');

    IF LENGTH(v_input) <> 19 THEN
        RAISE EXCEPTION 'Invalid parameters: Input must total 19 characters.';
    END IF;

    -- Iterating backwards using modular multiplication prevents 32/64-bit integer overflow
    FOR i IN REVERSE 19..1 LOOP
        v_char := SUBSTRING(v_input FROM i FOR 1);
        v_pos := POSITION(v_char IN v_charset) - 1;

        IF v_pos < 0 THEN
            RAISE EXCEPTION 'Invalid character "%" in input', v_char;
        END IF;

        v_c1 := (v_c1 + v_pos * v_w1) % 37;
        v_c2 := (v_c2 + v_pos * v_w2) % 37;
        v_c3 := (v_c3 + v_pos * v_w3) % 37;

        v_w1 := (v_w1 * 2) % 37;
        v_w2 := (v_w2 * 3) % 37;
        v_w3 := (v_w3 * 5) % 37;
    END LOOP;

    RETURN v_first9 || 
           SUBSTRING(v_charset FROM v_c1 + 1 FOR 1) || 
           SUBSTRING(v_charset FROM v_c2 + 1 FOR 1) || 
           SUBSTRING(v_charset FROM v_c3 + 1 FOR 1);
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

---

### 4.2 SQL Server (T-SQL)

```sql
CREATE OR ALTER FUNCTION dbo.GenerateRioCode (
    @OperatorCode VARCHAR(2),   -- OO
    @AccountType CHAR(1),       -- Q
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

    SET @First9 = UPPER(RIGHT('00' + ISNULL(@OperatorCode, ''), 2)) + 
                  UPPER(ISNULL(@AccountType, '')) + 
                  UPPER(RIGHT('000000' + ISNULL(@ContractRef, ''), 6));
                  
    SET @Input = @First9 + ISNULL(@PhoneNumber, '');

    IF LEN(@Input) <> 19
        RETURN NULL;

    WHILE @I >= 1
    BEGIN
        SET @Char = SUBSTRING(@Input, @I, 1);
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

    RETURN @First9 + 
           SUBSTRING(@Charset, @C1 + 1, 1) + 
           SUBSTRING(@Charset, @C2 + 1, 1) + 
           SUBSTRING(@Charset, @C3 + 1, 1);
END;
GO
```

---

### 4.3 MySQL / MariaDB

```sql
DELIMITER //

CREATE FUNCTION generate_rio_code(
    p_operator_code VARCHAR(2),
    p_account_type CHAR(1),
    p_contract_ref VARCHAR(6),
    p_phone_number VARCHAR(10)
)
RETURNS VARCHAR(12)
DETERMINISTIC
BEGIN
    DECLARE v_charset VARCHAR(37) DEFAULT '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ+';
    DECLARE v_first9 VARCHAR(9);
    DECLARE v_input VARCHAR(19);
    DECLARE v_char CHAR(1);
    DECLARE v_pos INT;
    DECLARE v_c1 INT DEFAULT 0;
    DECLARE v_c2 INT DEFAULT 0;
    DECLARE v_c3 INT DEFAULT 0;
    DECLARE v_w1 INT DEFAULT 2;
    DECLARE v_w2 INT DEFAULT 3;
    DECLARE v_w3 INT DEFAULT 5;
    DECLARE i INT DEFAULT 19;

    SET v_first9 = CONCAT(
        UPPER(LPAD(p_operator_code, 2, '0')),
        UPPER(p_account_type),
        UPPER(LPAD(p_contract_ref, 6, '0'))
    );
    
    SET v_input = CONCAT(v_first9, p_phone_number);

    IF CHAR_LENGTH(v_input) <> 19 THEN
        RETURN NULL;
    END IF;

    WHILE i >= 1 DO
        SET v_char = SUBSTRING(v_input, i, 1);
        SET v_pos = INSTR(v_charset, v_char) - 1;

        IF v_pos < 0 THEN
            RETURN NULL;
        END IF;

        SET v_c1 = (v_c1 + v_pos * v_w1) % 37;
        SET v_c2 = (v_c2 + v_pos * v_w2) % 37;
        SET v_c3 = (v_c3 + v_pos * v_w3) % 37;

        SET v_w1 = (v_w1 * 2) % 37;
        SET v_w2 = (v_w2 * 3) % 37;
        SET v_w3 = (v_w3 * 5) % 37;

        SET i = i - 1;
    END WHILE;

    RETURN CONCAT(
        v_first9,
        SUBSTRING(v_charset, v_c1 + 1, 1),
        SUBSTRING(v_charset, v_c2 + 1, 1),
        SUBSTRING(v_charset, v_c3 + 1, 1)
    );
END //

DELIMITER ;
```

---

## 5. Security & Regulatory Compliance

1. **ARCEP Compliance**:
   Under ARCEP regulations, operators are obligated to provide consumers with their valid RIO code 24/7 free of charge via short code **3179**.
2. **Number Portability Workflow**:
   When a subscriber initiates a porting request with a recipient operator, the recipient operator submits the 12-character RIO code to the central porting entity (GIE EGP for mobile, APNF for fixed lines). The losing operator validates the RIO against its customer database before authorizing number release.

