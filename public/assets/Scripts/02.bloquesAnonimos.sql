-- ============================================================
-- Archivo: 02_bloques_anonimos.sql
-- Autoras: Santiago Rojas Galeano
-- Curso:   Bases de Datos 2
-- Temas:   Variables, IF, WHILE, LOOP, Fibonacci, MCM, cursores
-- ============================================================

SET SERVEROUTPUT ON;


-- -------------------------------------------------------
-- CONVENCIONES DE NOMENCLATURA 
--
--   v_xxx      → variable genérica
--   vv_xxx     → variable VARCHAR2
--   vn_xxx     → variable NUMBER
--   vd_xxx     → variable DATE
--   vb_xxx     → variable BOOLEAN
--   cn_xxx     → constante NUMBER
-- -------------------------------------------------------


-- -------------------------------------------------------
-- 1. Primera variable: imprimir "Hola Mundo"
-- -------------------------------------------------------
DECLARE
    vv_miPrimeraVariable VARCHAR2(50);
BEGIN
    vv_miPrimeraVariable := 'Hola Mundo';
    DBMS_OUTPUT.PUT_LINE(vv_miPrimeraVariable);
END;
/


-- -------------------------------------------------------
-- 2. ¿El día de hoy es un número primo?
--    Si lo es → imprime "HOLA PRIMO"
-- -------------------------------------------------------
DECLARE
    vd_current_date NUMBER := TO_NUMBER(TO_CHAR(SYSDATE, 'DD'));
BEGIN
    IF vd_current_date IN (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31) THEN
        DBMS_OUTPUT.PUT_LINE('HOLA PRIMO - El día ' || vd_current_date || ' es primo');
    ELSE
        DBMS_OUTPUT.PUT_LINE('NO ES PRIMO - El día es: ' || vd_current_date);
    END IF;
END;
/


-- -------------------------------------------------------
-- 3a. Serie de Fibonacci ≤ 100 con WHILE
--     Imprime todos los términos en una sola línea
-- -------------------------------------------------------
DECLARE
    vn_a NUMBER := 0;
    vn_b NUMBER := 1;
BEGIN
    WHILE vn_a <= 100 LOOP
        DBMS_OUTPUT.PUT(vn_a || ' ');
        vn_b := vn_a + vn_b;
        vn_a := vn_b - vn_a;
    END LOOP;
    DBMS_OUTPUT.NEW_LINE;
END;
/


-- -------------------------------------------------------
-- 3b. Serie de Fibonacci (primeros 100 términos) con LOOP
--     Imprime número de término + valor
-- -------------------------------------------------------
DECLARE
    n1   NUMBER := 0;
    n2   NUMBER := 1;
    cont NUMBER;
    i    NUMBER := 1;
BEGIN
    LOOP
        DBMS_OUTPUT.PUT_LINE(i || ': ' || n1);
        cont := n1 + n2;
        n1   := n2;
        n2   := cont;
        i    := i + 1;
        EXIT WHEN i > 100;
    END LOOP;
END;
/


-- -------------------------------------------------------
-- 4. Mínimo Común Múltiplo (MCM) con WHILE
--    Calcula el MCM de dos números (15 y 12)
-- -------------------------------------------------------
DECLARE
    vn_num1 NUMBER  := 15;
    vn_num2 NUMBER  := 12;
    vn_mcm  NUMBER  := GREATEST(vn_num1, vn_num2);
    vb_x    BOOLEAN := TRUE;
BEGIN
    WHILE vb_x LOOP
        IF MOD(vn_mcm, vn_num1) = 0 AND MOD(vn_mcm, vn_num2) = 0 THEN
            DBMS_OUTPUT.PUT_LINE(
                'El MCM de ' || vn_num1 || ' y ' || vn_num2 || ' es: ' || vn_mcm
            );
            vb_x := FALSE;
        ELSE
            vn_mcm := vn_mcm + 1;
        END IF;
    END LOOP;
END;
/


-- -------------------------------------------------------
-- 5. Cursor EXPLÍCITO — Empleados del departamento 80
--    Muestra: nombre completo, cargo y salario
-- -------------------------------------------------------
DECLARE
    -- Definición del cursor
    CURSOR cur_emp_dept80 IS
        SELECT
            e.FIRST_NAME || ' ' || e.LAST_NAME  AS nombre_completo,
            e.JOB_ID                             AS cargo,
            e.SALARY                             AS salario
        FROM hr.EMPLOYEES e
        WHERE e.DEPARTMENT_ID = 80
        ORDER BY e.LAST_NAME;

    -- Variable de registro para recibir cada fila
    vr_empleado cur_emp_dept80%ROWTYPE;
BEGIN
    OPEN cur_emp_dept80;

    LOOP
        FETCH cur_emp_dept80 INTO vr_empleado;
        EXIT WHEN cur_emp_dept80%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(vr_empleado.nombre_completo, 30) ||
            RPAD(vr_empleado.cargo, 15)           ||
            'Salario: $' || vr_empleado.salario
        );
    END LOOP;

    CLOSE cur_emp_dept80;
END;
/
