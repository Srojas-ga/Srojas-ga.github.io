-- ============================================================
-- Archivo: 04_triggers_excepciones.sql
-- Autoras: Santiago Rojas Galeano
-- Curso:   Bases de Datos 2
-- Temas:   Triggers DML (BEFORE/AFTER), excepciones predefinidas
--          y excepciones declaradas por el usuario
-- ============================================================

SET SERVEROUTPUT ON;


-- ============================================================
-- PARTE A — TRIGGERS
-- ============================================================

-- -------------------------------------------------------
-- Sintaxis general de un trigger
-- -------------------------------------------------------
--
--  CREATE [OR REPLACE] TRIGGER <nombre_trigger>
--  { BEFORE | AFTER }
--  { DELETE | INSERT | UPDATE [OF columna] }
--  ON <tabla>
--  [FOR EACH ROW]
--  [WHEN (condición)]
--  BEGIN
--      -- lógica del trigger
--  END <nombre_trigger>;
--  /


-- -------------------------------------------------------
-- Trigger AFTER INSERT — Auditoría de nuevos empleados
--
-- Registra en la tabla emp_audit_log cada vez que se
-- inserta un nuevo empleado en HR.EMPLOYEES.
--
-- Prerequisito: crear la tabla de auditoría primero.
-- -------------------------------------------------------

-- Tabla de auditoría (ejecutar una sola vez)
CREATE TABLE emp_audit_log (
    audit_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id   NUMBER,
    accion        VARCHAR2(10)   DEFAULT 'INSERT',
    usuario       VARCHAR2(50),
    fecha         DATE           DEFAULT SYSDATE
);

-- Trigger
CREATE OR REPLACE TRIGGER trg_after_insert_empleado
AFTER INSERT
ON hr.EMPLOYEES
FOR EACH ROW
/*
   Autor:      Estefania Paredes Castañeda
   Fecha:      2026
   Descripción: Registra en emp_audit_log cada nuevo empleado insertado.
*/
BEGIN
    INSERT INTO emp_audit_log (employee_id, accion, usuario, fecha)
    VALUES (:NEW.EMPLOYEE_ID, 'INSERT', USER, SYSDATE);
END trg_after_insert_empleado;
/


-- -------------------------------------------------------
-- Trigger BEFORE UPDATE — Validar que el salario no baje
--
-- Lanza un error si se intenta reducir el salario de un
-- empleado existente.
-- -------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_before_update_salario
BEFORE UPDATE OF SALARY
ON hr.EMPLOYEES
FOR EACH ROW
/*
   Autor:      Estefania Paredes Castañeda
   Fecha:      2026
   Descripción: Impide que el salario de un empleado sea reducido.
*/
BEGIN
    IF :NEW.SALARY < :OLD.SALARY THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Error: no se puede reducir el salario. ' ||
            'Actual: ' || :OLD.SALARY ||
            ' → Nuevo: ' || :NEW.SALARY
        );
    END IF;
END trg_before_update_salario;
/


-- ============================================================
-- PARTE B — MANEJO DE EXCEPCIONES
-- ============================================================

-- -------------------------------------------------------
-- 1. Excepción predefinida: división por cero (ZERO_DIVIDE)
-- -------------------------------------------------------
DECLARE
    v_1   NUMBER(9) := 3;
    v_2   NUMBER(9) := 0;
    total NUMBER(9);
BEGIN
    total := v_1 / v_2;
    DBMS_OUTPUT.PUT_LINE('Resultado: ' || total);
EXCEPTION
    WHEN ZERO_DIVIDE THEN
        DBMS_OUTPUT.PUT_LINE('Error: división por cero.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error inesperado: ' || SQLERRM);
END;
/


-- -------------------------------------------------------
-- 2. Excepción predefinida: NO_DATA_FOUND
--    Se dispara cuando un SELECT INTO no retorna filas.
-- -------------------------------------------------------
DECLARE
    vv_nombre hr.EMPLOYEES.FIRST_NAME%TYPE;
BEGIN
    SELECT FIRST_NAME
    INTO   vv_nombre
    FROM   hr.EMPLOYEES
    WHERE  EMPLOYEE_ID = 99999; -- ID que no existe

    DBMS_OUTPUT.PUT_LINE('Empleado: ' || vv_nombre);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Error: no se encontró el empleado.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error inesperado: ' || SQLERRM);
END;
/


-- -------------------------------------------------------
-- 3. Excepción declarada por el usuario
--    Valida que el salario sea positivo antes de insertar.
--
--    Convención: exc_nombredelaexcepcion
-- -------------------------------------------------------
DECLARE
    exc_salario_invalido EXCEPTION;
    vn_salario           NUMBER := -500;   -- valor de prueba
BEGIN
    IF vn_salario <= 0 THEN
        RAISE exc_salario_invalido;
    END IF;

    DBMS_OUTPUT.PUT_LINE('Salario válido: ' || vn_salario);

EXCEPTION
    WHEN exc_salario_invalido THEN
        DBMS_OUTPUT.PUT_LINE(
            'Error de negocio: el salario debe ser mayor a cero. ' ||
            'Valor recibido: ' || vn_salario
        );
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error inesperado: ' || SQLERRM);
END;
/
