-- ============================================================
-- Archivo: 03_procedimientos.sql
-- Autoras: Santiago Rojas Galeano
-- Curso:   Bases de Datos 2
-- Temas:   Stored procedures, parámetros IN, GRANT de permisos
-- ============================================================

SET SERVEROUTPUT ON;


-- -------------------------------------------------------
-- 1. Procedimiento: sp_saludoo
--    Recibe un texto y lo imprime con "Hola mundo"
--
--    Convención de nomenclatura del SP:
--      param_xxx  → parámetro de entrada (IN)
--      vv_xxx     → variable local VARCHAR2
-- -------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_saludoo (
    param_texto IN VARCHAR2
)
/*
   Autor:      Estefania Paredes Castañeda
   Fecha:      23/02/2026
   Descripción: Recibe un nombre y genera un saludo personalizado.
   Parámetros:
     param_texto IN  → texto/nombre a incluir en el saludo
*/
IS
    vv_textoConcatenado VARCHAR2(100);
BEGIN
    vv_textoConcatenado := 'Hola mundo ' || param_texto;
    DBMS_OUTPUT.PUT_LINE(vv_textoConcatenado);
END sp_saludoo;
/


-- -------------------------------------------------------
-- 2. Ejecución del procedimiento sp_saludoo
-- -------------------------------------------------------
BEGIN
    sp_saludoo('Vivienne Westwood');
END;
/


-- -------------------------------------------------------
-- 3. Gestión de permisos entre esquemas (DML)
--
--    Otorga permisos sobre la tabla EMPLOYEES del esquema
--    actual al usuario mvosorio.
--
--    NOTA: ejecutar como el dueño de la tabla o como DBA.
-- -------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE
    ON EMPLOYEES
    TO mvosorio;
