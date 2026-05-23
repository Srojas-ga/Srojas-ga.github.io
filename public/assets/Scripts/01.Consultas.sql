-- ============================================================
-- Archivo: 01_consultas_hr.sql
-- Autoras: Santiago Rojas Galeano - Estefania Paredes Castañeda
-- Curso:   Bases de Datos 2
-- Temas:   LEFT JOIN, GROUP BY, HAVING, funciones de cadena,
--          jerarquía de empleados (self-join), filtros por región
-- ============================================================


-- -------------------------------------------------------
-- 1. Cuántos cargos ha tenido cada empleado
--    (incluye empleados sin historial → COUNT = 0)
-- -------------------------------------------------------
SELECT
    e.EMPLOYEE_ID                          AS ID,
    e.FIRST_NAME || ' ' || e.LAST_NAME     AS NOMBRE_COMPLETO,
    COUNT(hc.JOB_ID)                       AS NUMERO_CARGOS
FROM hr.EMPLOYEES e
LEFT JOIN hr.JOB_HISTORY hc
    ON e.EMPLOYEE_ID = hc.EMPLOYEE_ID
GROUP BY e.EMPLOYEE_ID, e.FIRST_NAME, e.LAST_NAME
ORDER BY NUMERO_CARGOS DESC;


-- -------------------------------------------------------
-- 2. Empleados que han tenido MÁS de un cargo (mínimo 2)
-- -------------------------------------------------------
SELECT
    e.EMPLOYEE_ID                          AS ID,
    e.FIRST_NAME || ' ' || e.LAST_NAME     AS NOMBRE_COMPLETO,
    COUNT(hc.JOB_ID)                       AS NUMERO_CARGOS
FROM hr.EMPLOYEES e
LEFT JOIN hr.JOB_HISTORY hc
    ON e.EMPLOYEE_ID = hc.EMPLOYEE_ID
GROUP BY e.EMPLOYEE_ID, e.FIRST_NAME, e.LAST_NAME
HAVING COUNT(hc.JOB_ID) > 1
ORDER BY e.EMPLOYEE_ID;


-- -------------------------------------------------------
-- 3. Empleados en Europa con salario entre $4.000 y $6.000
--    Muestra: nombre completo, país, salario
--
--    NOTA: el filtro original usaba MIN_SALARY/MAX_SALARY
--    del job; se corrige para filtrar el salario real del
--    empleado (e.SALARY) en el rango solicitado.
-- -------------------------------------------------------
SELECT
    INITCAP(e.FIRST_NAME || ' ' || e.LAST_NAME)  AS NOMBRE_COMPLETO,
    e.SALARY                                      AS SALARIO,
    c.COUNTRY_NAME                                AS PAIS
FROM hr.EMPLOYEES e
LEFT JOIN hr.DEPARTMENTS  d  ON e.DEPARTMENT_ID = d.DEPARTMENT_ID
LEFT JOIN hr.LOCATIONS    l  ON d.LOCATION_ID   = l.LOCATION_ID
LEFT JOIN hr.COUNTRIES    c  ON l.COUNTRY_ID    = c.COUNTRY_ID
LEFT JOIN hr.REGIONS      r  ON c.REGION_ID     = r.REGION_ID
WHERE r.REGION_NAME = 'Europe'
  AND e.SALARY BETWEEN 4000 AND 6000
ORDER BY e.SALARY;


-- -------------------------------------------------------
-- 4. Jerarquía empleado → jefe con emails enmascarados
--    Formato email: primeras 3 letras + 6 asteriscos
--    Ejemplo: "STE******"  (total 9 caracteres con LPAD)
-- -------------------------------------------------------
SELECT
    E.FIRST_NAME || ' ' || E.LAST_NAME          AS EMPLEADO,
    LPAD(SUBSTR(E.EMAIL, 1, 3), 9, '*')          AS EMAIL_EMPLEADO,
    M.FIRST_NAME || ' ' || M.LAST_NAME          AS JEFE,
    LPAD(SUBSTR(M.EMAIL, 1, 3), 9, '*')          AS EMAIL_JEFE
FROM hr.EMPLOYEES E
LEFT JOIN hr.EMPLOYEES M
    ON E.MANAGER_ID = M.EMPLOYEE_ID
ORDER BY E.LAST_NAME;
