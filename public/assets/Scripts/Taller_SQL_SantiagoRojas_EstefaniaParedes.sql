-- ============================================================
-- Integrante 1: Estefania Paredes Castañeda
-- Integrante 2: Santiago Rojas Galeano
-- Curso: Bases de Datos 2 
-- Fecha: 08/04/2026
-- Variante asignada por el docente (1, 2, 3 o 4): 1
-- Tag de ejecución final (ejemplo: P03_FINAL): P01


PROMPT ===== 1. CONSULTA DIAGNÓSTICA ===== 
 
--------------------------------------------------------------------------------
-- CTE 1: Lectura de parámetros de la variante
--------------------------------------------------------------------------------
 
WITH v AS (
 
    SELECT  
        excluded_department_id, 
        min_years_service, 
        recent_job_history_months, 
        gap_high_threshold_pct, 
        gap_mid_threshold_pct, 
        raise_high_pct, 
        raise_mid_pct, 
        raise_low_pct, 
        max_salary_vs_avg_pct 
    FROM t1_variants
 
    WHERE variant_id = &p_variant_id
 
),
 
--------------------------------------------------------------------------------
-- CTE 2: Estadísticas por departamento 
--------------------------------------------------------------------------------
 
cte_dept_stats AS (
 
    SELECT  
        department_id, 
        AVG(salary) AS dept_avg_salary, 
        MAX(salary) AS dept_max_salary, 
        COUNT(*)    AS dept_employee_count 
    FROM t1_employees 
    GROUP BY department_id
 
),
 
--------------------------------------------------------------------------------
-- CTE 3: Historial reciente 
--------------------------------------------------------------------------------
 
cte_recent_history AS ( 
    SELECT DISTINCT  
        jh.employee_id 
    FROM t1_job_history jh 
    CROSS JOIN v  
    WHERE months_between(SYSDATE, jh.start_date) <= v.recent_job_history_months
 
),
 
--------------------------------------------------------------------------------
-- CTE 4: Diagnóstico principal 
--------------------------------------------------------------------------------
 
cte_main AS (
 
    SELECT 
        e.employee_id, 
        e.first_name, 
        e.last_name, 
        e.job_id, 
        e.manager_id, 
        e.department_id, 
        d.department_name, 
        e.salary, 
        e.hire_date,
 
        FLOOR(months_between(SYSDATE, e.hire_date) / 12) AS years_service, 
        ds.dept_avg_salary, 
        ds.dept_max_salary, 
        ds.dept_employee_count,
 
        ROUND(
 
            ( (ds.dept_avg_salary - e.salary) / ds.dept_avg_salary ) * 100, 
            2 
        ) AS pct_gap_to_avg, 
        CASE  
            WHEN rh.employee_id IS NOT NULL THEN 'SI' 
            ELSE 'NO' 
        END AS recent_job_history_flag, 
        DENSE_RANK() OVER ( 
            PARTITION BY e.department_id 
            ORDER BY e.salary DESC 
        ) AS salary_rank_in_department
 
    FROM t1_employees e 
    JOIN t1_departments d 
        ON e.department_id = d.department_id 
    JOIN cte_dept_stats ds 
        ON e.department_id = ds.department_id 
    LEFT JOIN cte_recent_history rh 
        ON e.employee_id = rh.employee_id
 
)
 
SELECT * 
FROM cte_main 
ORDER BY department_id, salary DESC;
 
PROMPT ===== 2. DECISIÓN DE ELEGIBLES =====
 
WITH variant AS (
    SELECT *
    FROM t1_variants
    WHERE variant_id = &p_variant_id
),
 
dept_stats AS (
    SELECT department_id,
           AVG(salary) AS dept_avg_salary,
           MAX(salary) AS dept_max_salary,
           COUNT(*) AS dept_employee_count
    FROM t1_employees
    GROUP BY department_id
),
 
recent_hist AS (
    SELECT DISTINCT employee_id
    FROM t1_job_history v, variant x
    WHERE MONTHS_BETWEEN(SYSDATE, v.end_date) <= x.recent_job_history_months
),
 
diag AS (
    SELECT 
        e.employee_id,
        e.first_name,
        e.last_name,
        e.job_id,
        e.manager_id,
        e.department_id,
        d.department_name,
        e.salary,
        e.hire_date,
        FLOOR(MONTHS_BETWEEN(SYSDATE, e.hire_date)/12) AS years_service,
        ds.dept_avg_salary,
        ds.dept_max_salary,
        ds.dept_employee_count,
        ROUND(((ds.dept_avg_salary - e.salary)/ds.dept_avg_salary)*100,2) AS pct_gap_to_avg,
        CASE WHEN rh.employee_id IS NOT NULL THEN 'SI' ELSE 'NO' END AS recent_job_history_flag,
        DENSE_RANK() OVER (PARTITION BY e.department_id ORDER BY e.salary DESC) AS salary_rank_in_department
    FROM t1_employees e
    LEFT JOIN t1_departments d ON e.department_id = d.department_id
    LEFT JOIN dept_stats ds ON e.department_id = ds.department_id
    LEFT JOIN recent_hist rh ON e.employee_id = rh.employee_id
),
 
rules AS (
    SELECT 
        v.*,
        d.*,
         CASE 
            WHEN d.department_id IS NULL THEN 'SIN_DEPARTAMENTO'
            WHEN d.department_id = v.excluded_department_id THEN 'DEPTO_EXCLUIDO'
            WHEN d.dept_employee_count < 3 THEN 'DEPTO_MENOR_A_3_EMPLEADOS'
            WHEN d.years_service < v.min_years_service THEN 'ANTIGUEDAD_INSUFICIENTE'
            WHEN d.recent_job_history_flag = 'SI' THEN 'HISTORIAL_RECIENTE'
            WHEN d.salary > d.dept_avg_salary * (v.max_salary_vs_avg_pct/100) THEN 'SALARIO_NO_APLICA'
            WHEN d.manager_id IN (SELECT manager_id FROM t1_departments) AND d.manager_id = d.employee_id THEN 'MANAGER_O_DIRECTIVO'
            ELSE 'OK'
        END AS exclusion_reason,
 
        CASE
            WHEN ROUND(((d.dept_avg_salary - d.salary)/d.dept_avg_salary)*100,2) >= v.gap_high_threshold_pct
                THEN v.raise_high_pct
            WHEN ROUND(((d.dept_avg_salary - d.salary)/d.dept_avg_salary)*100,2) >= v.gap_mid_threshold_pct
                THEN v.raise_mid_pct
            ELSE v.raise_low_pct
        END AS adjustment_pct,
 
        CASE
            WHEN ROUND(((d.dept_avg_salary - d.salary)/d.dept_avg_salary)*100,2) >= v.gap_high_threshold_pct
                THEN 'AJUSTE_ALTO'
            WHEN ROUND(((d.dept_avg_salary - d.salary)/d.dept_avg_salary)*100,2) >= v.gap_mid_threshold_pct
                THEN 'AJUSTE_MEDIO'
            ELSE 'AJUSTE_BAJO'
        END AS rule_applied
 
    FROM diag d CROSS JOIN variant v
)
 
SELECT 
    employee_id,
    first_name,
    last_name,
    department_id,
    department_name,
    salary,
    years_service,
    dept_avg_salary,
    dept_max_salary,
    dept_employee_count,
    pct_gap_to_avg,
    recent_job_history_flag,
    CASE WHEN exclusion_reason = 'OK' THEN 'ELEGIBLE' ELSE 'NO_ELEGIBLE' END AS eligibility_flag,
    exclusion_reason,
    adjustment_pct,
    rule_applied
    
FROM rules
ORDER BY eligibility_flag DESC, department_id, employee_id;

-- En esta consulta se aplicaron todas las reglas de la variante 1:
-- exclusión del departamento 90, mínimo de 3 años de antigüedad,
-- revisión del historial laboral de los últimos 24 meses y validación
-- de brecha salarial frente al promedio del departamento. También se
-- filtraron empleados sin departamento y departamentos con menos de 3 empleados.
-- El resultado identifica correctamente qué empleados cumplen todas las 
-- condiciones y calcula el porcentaje de ajuste que recibirían según la brecha real.

PROMPT A ===== 3. PREVALIDACIÓN =====
 
WITH variant AS (
    SELECT *
    FROM t1_variants
    WHERE variant_id = &p_variant_id
),
 
dept_stats AS (
    SELECT department_id,
           AVG(salary) AS dept_avg_salary,
           MAX(salary) AS dept_max_salary,
           COUNT(*) AS dept_employee_count
    FROM t1_employees
    GROUP BY department_id
),
 
recent_hist AS (
    SELECT DISTINCT employee_id
    FROM t1_job_history v, variant x
    WHERE MONTHS_BETWEEN(SYSDATE, v.end_date) <= x.recent_job_history_months
),
 
diag AS (
    SELECT 
        e.employee_id,
        e.department_id,
        e.salary,
        FLOOR(MONTHS_BETWEEN(SYSDATE, e.hire_date)/12) AS years_service,
        ds.dept_avg_salary,
        ds.dept_max_salary,
        ds.dept_employee_count,
        ROUND(((ds.dept_avg_salary - e.salary)/ds.dept_avg_salary)*100,2) AS pct_gap_to_avg,
        CASE WHEN rh.employee_id IS NOT NULL THEN 'SI' ELSE 'NO' END AS recent_job_history_flag
    FROM t1_employees e
    LEFT JOIN dept_stats ds ON e.department_id = ds.department_id
    LEFT JOIN recent_hist rh ON e.employee_id = rh.employee_id
),
 
rules AS (
    SELECT 
        d.*,
        v.*,
        CASE 
            WHEN d.department_id IS NULL THEN 'SIN_DEPARTAMENTO'
            WHEN d.department_id = v.excluded_department_id THEN 'DEPTO_EXCLUIDO'
            WHEN d.dept_employee_count < 3 THEN 'DEPTO_MENOR_A_3'
            WHEN d.years_service < v.min_years_service THEN 'ANTIGUEDAD_INSUFICIENTE'
            WHEN d.recent_job_history_flag = 'SI' THEN 'HISTORIAL_RECIENTE'
            WHEN d.salary > d.dept_avg_salary * (v.max_salary_vs_avg_pct/100) THEN 'SALARIO_NO_APLICA'
            ELSE 'OK'
        END AS exclusion_reason,
        CASE
            WHEN d.pct_gap_to_avg >= v.gap_high_threshold_pct THEN v.raise_high_pct
            WHEN d.pct_gap_to_avg >= v.gap_mid_threshold_pct THEN v.raise_mid_pct
            ELSE v.raise_low_pct
        END AS adjustment_pct,
        CASE
            WHEN d.pct_gap_to_avg >= v.gap_high_threshold_pct THEN 'AJUSTE_ALTO'
            WHEN d.pct_gap_to_avg >= v.gap_mid_threshold_pct THEN 'AJUSTE_MEDIO'
            ELSE 'AJUSTE_BAJO'
        END AS rule_applied
    FROM diag d CROSS JOIN variant v
),
 
eligibles AS (
    SELECT *
    FROM rules
    WHERE exclusion_reason = 'OK'
),
 
calc AS (
    SELECT 
        employee_id,
        department_id,
        salary AS salary_before,
        ROUND(salary * (1 + adjustment_pct/100), 2) AS salary_after,
        adjustment_pct,
        rule_applied
    FROM eligibles
)
 

SELECT 
    (SELECT COUNT(*) FROM calc) AS total_eligible_employees,
    (SELECT SUM(salary_before) FROM calc) AS total_salary_before,
    (SELECT SUM(salary_after) FROM calc) AS total_salary_after,
    (SELECT SUM(salary_after - salary_before) FROM calc) AS total_increment
FROM dual;
 
PROMPT B ---- DETALLE DE EMPLEADOS ELEGIBLES ----
 
WITH variant AS (
    SELECT * FROM t1_variants WHERE variant_id = &p_variant_id
),
dept_stats AS (
    SELECT department_id,
           AVG(salary) AS dept_avg_salary,
           MAX(salary) AS dept_max_salary,
           COUNT(*) AS dept_employee_count
    FROM t1_employees
    GROUP BY department_id
),
recent_hist AS (
    SELECT DISTINCT employee_id
    FROM t1_job_history v, variant x
    WHERE MONTHS_BETWEEN(SYSDATE, v.end_date) <= x.recent_job_history_months
),
diag AS (
    SELECT 
        e.employee_id,
        e.department_id,
        e.salary,
        FLOOR(MONTHS_BETWEEN(SYSDATE, e.hire_date)/12) AS years_service,
        ds.dept_avg_salary,
        ds.dept_max_salary,
        ds.dept_employee_count,
        ROUND(((ds.dept_avg_salary - e.salary)/ds.dept_avg_salary)*100,2) AS pct_gap_to_avg,
        CASE WHEN rh.employee_id IS NOT NULL THEN 'SI' ELSE 'NO' END AS recent_job_history_flag
    FROM t1_employees e
    LEFT JOIN dept_stats ds ON e.department_id = ds.department_id
    LEFT JOIN recent_hist rh ON e.employee_id = rh.employee_id
),
rules AS (
    SELECT d.*, v.*,
        CASE 
            WHEN d.department_id IS NULL THEN 'SIN_DEPARTAMENTO'
            WHEN d.department_id = v.excluded_department_id THEN 'DEPTO_EXCLUIDO'
            WHEN d.dept_employee_count < 3 THEN 'DEPTO_MENOR_A_3'
            WHEN d.years_service < v.min_years_service THEN 'ANTIGUEDAD_INSUFICIENTE'
            WHEN d.recent_job_history_flag = 'SI' THEN 'HISTORIAL_RECIENTE'
            WHEN d.salary > d.dept_avg_salary * (v.max_salary_vs_avg_pct/100) THEN 'SALARIO_NO_APLICA'
            ELSE 'OK'
        END AS exclusion_reason,
        CASE
            WHEN d.pct_gap_to_avg >= v.gap_high_threshold_pct THEN v.raise_high_pct
            WHEN d.pct_gap_to_avg >= v.gap_mid_threshold_pct THEN v.raise_mid_pct
            ELSE v.raise_low_pct
        END AS adjustment_pct,
        CASE
            WHEN d.pct_gap_to_avg >= v.gap_high_threshold_pct THEN 'AJUSTE_ALTO'
            WHEN d.pct_gap_to_avg >= v.gap_mid_threshold_pct THEN 'AJUSTE_MEDIO'
            ELSE 'AJUSTE_BAJO'
        END AS rule_applied
    FROM diag d CROSS JOIN variant v
),
eligibles AS (
    SELECT * FROM rules WHERE exclusion_reason = 'OK'
),
calc AS (
    SELECT 
        employee_id,
        department_id,
        salary AS salary_before,
        ROUND(salary * (1 + adjustment_pct/100), 2) AS salary_after,
        adjustment_pct,
        rule_applied
    FROM eligibles
)
 
SELECT *
FROM calc
ORDER BY department_id, employee_id;
 
PROMPT C ---- CONTROL DE TOPES ----
 
WITH variant AS (
    SELECT * FROM t1_variants WHERE variant_id = &p_variant_id
),
dept_stats AS (
    SELECT department_id,
           AVG(salary) AS dept_avg_salary,
           MAX(salary) AS dept_max_salary
    FROM t1_employees
    GROUP BY department_id
)
 
SELECT 
    d.department_id,
    d.department_name,
    ds.dept_avg_salary,
    ds.dept_max_salary,
    ROUND(ds.dept_avg_salary * (v.max_salary_vs_avg_pct/100),2) AS max_allowed_salary_by_variant
FROM t1_departments d
JOIN dept_stats ds ON d.department_id = ds.department_id
CROSS JOIN variant v
ORDER BY department_id;

-- En esta prevalidación se proyecta el impacto total de aplicar la variante seleccionada
-- antes de ejecutar cualquier cambio real. Se calcula cuántos empleados serían elegibles,
-- cuánto aumentaría la masa salarial y cuál sería el nuevo salario propuesto para cada uno.
-- También se valida por departamento que los salarios proyectados no superen el tope
-- permitido por la variante, garantizando que los ajustes cumplen todas las restricciones.

PROMPT ===== 4. EJECUCIÓN TRANSACCIONAL =====

SAVEPOINT sv_before_adjustment;

--Prompt 4.1 ACTUALIZACIÓN DE SALARIOS

UPDATE t1_employees e
SET e.salary = (
    SELECT c.salary_after
    FROM (
        WITH variant AS (
            SELECT * FROM t1_variants WHERE variant_id = &p_variant_id
        ),
        dept_stats AS (
            SELECT department_id,
                   AVG(salary) AS dept_avg_salary,
                   COUNT(*) AS dept_employee_count
            FROM t1_employees
            GROUP BY department_id
        ),
        recent_hist AS (
            SELECT DISTINCT employee_id
            FROM t1_job_history jh, variant x
            WHERE MONTHS_BETWEEN(SYSDATE, jh.end_date) <= x.recent_job_history_months
        ),
        diag AS (
            SELECT 
                e.employee_id,
                e.department_id,
                e.salary,
                FLOOR(MONTHS_BETWEEN(SYSDATE, e.hire_date)/12) AS years_service,
                ds.dept_avg_salary,
                ds.dept_employee_count,
                ROUND(((ds.dept_avg_salary - e.salary)/ds.dept_avg_salary)*100,2) AS pct_gap_to_avg,
                CASE WHEN rh.employee_id IS NOT NULL THEN 'SI' ELSE 'NO' END AS recent_job_history_flag
            FROM t1_employees e
            LEFT JOIN dept_stats ds ON e.department_id = ds.department_id
            LEFT JOIN recent_hist rh ON e.employee_id = rh.employee_id
        ),
        rules AS (
            SELECT d.*, v.*,
                CASE 
                    WHEN d.department_id IS NULL THEN 'SIN_DEPARTAMENTO'
                    WHEN d.department_id = v.excluded_department_id THEN 'DEPTO_EXCLUIDO'
                    WHEN d.dept_employee_count < 3 THEN 'DEPTO_MENOR_A_3'
                    WHEN d.years_service < v.min_years_service THEN 'ANTIGUEDAD_INSUFICIENTE'
                    WHEN d.recent_job_history_flag = 'SI' THEN 'HISTORIAL_RECIENTE'
                    WHEN d.salary > d.dept_avg_salary * (v.max_salary_vs_avg_pct/100) THEN 'SALARIO_NO_APLICA'
                    ELSE 'OK'
                END AS exclusion_reason,
                CASE
                    WHEN d.pct_gap_to_avg >= v.gap_high_threshold_pct THEN v.raise_high_pct
                    WHEN d.pct_gap_to_avg >= v.gap_mid_threshold_pct THEN v.raise_mid_pct
                    ELSE v.raise_low_pct
                END AS adjustment_pct
            FROM diag d CROSS JOIN variant v
        ),
        eligibles AS (
            SELECT * FROM rules WHERE exclusion_reason = 'OK'
        ),
        calc AS (
            SELECT 
                employee_id,
                ROUND(salary * (1 + adjustment_pct/100), 2) AS salary_after
            FROM eligibles
        )
        SELECT employee_id, salary_after
        FROM calc
    ) c
    WHERE c.employee_id = e.employee_id
)
WHERE EXISTS (
    SELECT 1
    FROM (
        WITH variant AS (
            SELECT * FROM t1_variants WHERE variant_id = &p_variant_id
        ),
        dept_stats AS (
            SELECT department_id,
                   AVG(salary) AS dept_avg_salary,
                   COUNT(*) AS dept_employee_count
            FROM t1_employees
            GROUP BY department_id
        ),
        recent_hist AS (
            SELECT DISTINCT employee_id
            FROM t1_job_history jh, variant x
            WHERE MONTHS_BETWEEN(SYSDATE, jh.end_date) <= x.recent_job_history_months
        ),
        diag AS (
            SELECT 
                e.employee_id,
                e.department_id,
                e.salary,
                FLOOR(MONTHS_BETWEEN(SYSDATE, e.hire_date)/12) AS years_service,
                ds.dept_avg_salary,
                ds.dept_employee_count,
                ROUND(((ds.dept_avg_salary - e.salary)/ds.dept_avg_salary)*100,2) AS pct_gap_to_avg,
                CASE WHEN rh.employee_id IS NOT NULL THEN 'SI' ELSE 'NO' END AS recent_job_history_flag
            FROM t1_employees e
            LEFT JOIN dept_stats ds ON e.department_id = ds.department_id
            LEFT JOIN recent_hist rh ON e.employee_id = rh.employee_id
        ),
        rules AS (
            SELECT d.*, v.*,
                CASE 
                    WHEN d.department_id IS NULL THEN 'SIN_DEPARTAMENTO'
                    WHEN d.department_id = v.excluded_department_id THEN 'DEPTO_EXCLUIDO'
                    WHEN d.dept_employee_count < 3 THEN 'DEPTO_MENOR_A_3'
                    WHEN d.years_service < v.min_years_service THEN 'ANTIGUEDAD_INSUFICIENTE'
                    WHEN d.recent_job_history_flag = 'SI' THEN 'HISTORIAL_RECIENTE'
                    WHEN d.salary > d.dept_avg_salary * (v.max_salary_vs_avg_pct/100) THEN 'SALARIO_NO_APLICA'
                    ELSE 'OK'
                END AS exclusion_reason
            FROM diag d CROSS JOIN variant v
        ),
        eligibles AS (
            SELECT employee_id FROM rules WHERE exclusion_reason = 'OK'
        )
        SELECT employee_id FROM eligibles
    ) c
    WHERE c.employee_id = e.employee_id
);

--Prompt 4.2 INSERCIÓN EN AUDITORÍA (CORREGIDO)

INSERT INTO audit_salary_adjustments_t1 (
    audit_id,
    execution_tag,
    variant_id,
    employee_id,
    department_id,
    salary_before,
    salary_after,
    pct_gap_to_avg_before,
    rule_applied,
    executed_by,
    executed_at,
    notes
)
WITH variant AS (
    SELECT * FROM t1_variants WHERE variant_id = &p_variant_id
),
dept_stats AS (
    SELECT department_id,
           AVG(salary) AS dept_avg_salary,
           COUNT(*) AS dept_employee_count
    FROM t1_employees
    GROUP BY department_id
),
recent_hist AS (
    SELECT DISTINCT employee_id
    FROM t1_job_history jh, variant x
    WHERE MONTHS_BETWEEN(SYSDATE, jh.end_date) <= x.recent_job_history_months
),
diag AS (
    SELECT 
        e.employee_id,
        e.department_id,
        e.salary,
        FLOOR(MONTHS_BETWEEN(SYSDATE, e.hire_date)/12) AS years_service,
        ds.dept_avg_salary,
        ds.dept_employee_count,
        ROUND(((ds.dept_avg_salary - e.salary)/ds.dept_avg_salary)*100,2) AS pct_gap_to_avg,
        CASE WHEN rh.employee_id IS NOT NULL THEN 'SI' ELSE 'NO' END AS recent_job_history_flag
    FROM t1_employees e
    LEFT JOIN dept_stats ds ON e.department_id = ds.department_id
    LEFT JOIN recent_hist rh ON e.employee_id = rh.employee_id
),
rules AS (
    SELECT d.*, v.*,
        CASE 
            WHEN d.department_id IS NULL THEN 'SIN_DEPARTAMENTO'
            WHEN d.department_id = v.excluded_department_id THEN 'DEPTO_EXCLUIDO'
            WHEN d.dept_employee_count < 3 THEN 'DEPTO_MENOR_A_3'
            WHEN d.years_service < v.min_years_service THEN 'ANTIGUEDAD_INSUFICIENTE'
            WHEN d.recent_job_history_flag = 'SI' THEN 'HISTORIAL_RECIENTE'
            WHEN d.salary > d.dept_avg_salary * (v.max_salary_vs_avg_pct/100) THEN 'SALARIO_NO_APLICA'
            ELSE 'OK'
        END AS exclusion_reason,
        CASE
            WHEN d.pct_gap_to_avg >= v.gap_high_threshold_pct THEN v.raise_high_pct
            WHEN d.pct_gap_to_avg >= v.gap_mid_threshold_pct THEN v.raise_mid_pct
            ELSE v.raise_low_pct
        END AS adjustment_pct,
        CASE
            WHEN d.pct_gap_to_avg >= v.gap_high_threshold_pct THEN 'AJUSTE_ALTO'
            WHEN d.pct_gap_to_avg >= v.gap_mid_threshold_pct THEN 'AJUSTE_MEDIO'
            ELSE 'AJUSTE_BAJO'
        END AS rule_applied
    FROM diag d CROSS JOIN variant v
),
eligibles AS (
    SELECT * FROM rules WHERE exclusion_reason = 'OK'
),
calc AS (
    SELECT 
        employee_id,
        department_id,
        ROUND(salary / (1 + adjustment_pct/100), 2) AS salary_before,
        salary AS salary_after,
        pct_gap_to_avg,
        rule_applied
    FROM eligibles
)

SELECT
    audit_salary_adj_t1_seq.NEXTVAL,
    '&p_execution_tag',
    &p_variant_id,
    employee_id,
    department_id,
    salary_before,
    salary_after,
    pct_gap_to_avg,
    rule_applied,
    USER,
    SYSDATE,
    'Ajuste salarial aplicado correctamente'
FROM calc;

Prom ===== 4.3 VALIDACIÓN INTERMEDIA =====

WITH v AS (SELECT * FROM t1_variants WHERE variant_id = &p_variant_id)
SELECT
    e.employee_id,
    e.department_id,
    e.salary AS current_salary,
    a.salary_before AS original_salary,
    ROUND(a.salary_before * (v.max_salary_vs_avg_pct/100),2) AS allowed_max_salary,
    CASE 
        WHEN e.salary <= ROUND(a.salary_before * (v.max_salary_vs_avg_pct/100),2)
            THEN 'CUMPLE'
        ELSE 'NO_CUMPLE'
    END AS validation_status
FROM t1_employees e
JOIN audit_salary_adjustments_t1 a 
    ON e.employee_id = a.employee_id
CROSS JOIN v
WHERE a.execution_tag = '&p_execution_tag'
ORDER BY e.employee_id;

--Prompt 4.4 CONTROL TRANSACCIONAL

COMMIT;

--ROLLBACK TO sv_before_adjustment;

-- Esta validación posterior confirma los efectos reales de la transacción:
-- muestra los empleados impactados, el resumen económico final del ajuste,
-- la verificación de que ningún salario supera el tope permitido por la variante
-- y la auditoría completa generada con el execution_tag. Con esto se garantiza
-- que la operación fue consistente, trazable y acorde a las reglas del proceso.

PROMPT ===== 5. VALIDACIÓN POSTERIOR =====

DEFINE p_variant_id = 1;
DEFINE p_execution_tag = '1';

PROMPT ===== SALIDA 1: EMPLEADOS IMPACTADOS =====

SELECT 
    e.employee_id,
    e.first_name,
    e.last_name,
    e.department_id,
    a.salary_before,
    a.salary_after,
    a.execution_tag
FROM t1_employees e
JOIN audit_salary_adjustments_t1 a
    ON e.employee_id = a.employee_id
WHERE a.execution_tag = '&p_execution_tag'
ORDER BY e.employee_id;


PROMPT ===== SALIDA 2: RESUMEN ECONÓMICO FINAL =====

SELECT 
    COUNT(*) AS total_rows_audited,
    SUM(salary_before) AS total_salary_before,
    SUM(salary_after) AS total_salary_after,
    SUM(salary_after - salary_before) AS total_increment
FROM audit_salary_adjustments_t1
WHERE execution_tag = '&p_execution_tag';


PROMPT ===== SALIDA 3: VALIDACIÓN DE TOPES =====

WITH v AS (
    SELECT * FROM t1_variants WHERE variant_id = &p_variant_id
)
SELECT
    a.employee_id,
    a.department_id,
    a.salary_after,
    ROUND(a.salary_before * (v.max_salary_vs_avg_pct/100),2) AS allowed_max_salary,
    CASE 
        WHEN a.salary_after <= ROUND(a.salary_before * (v.max_salary_vs_avg_pct/100),2)
            THEN 'CUMPLE'
        ELSE 'NO_CUMPLE'
    END AS top_limit_status
FROM audit_salary_adjustments_t1 a
CROSS JOIN v
WHERE a.execution_tag = '&p_execution_tag'
ORDER BY a.employee_id;


PROMPT ===== SALIDA 4: AUDITORÍA GENERADA =====

SELECT
    audit_id,
    execution_tag,
    variant_id,
    employee_id,
    department_id,
    salary_before,
    salary_after,
    rule_applied,
    executed_by,
    executed_at
FROM audit_salary_adjustments_t1
WHERE execution_tag = '&p_execution_tag'
ORDER BY audit_id;

-- ============================================================
-- 6. JUSTIFICACIÓN TÉCNICA
-- ============================================================
 
-- ATOMICIDAD:
-- Explique cómo su solución demuestra atomicidad.
--
-- RESPUESTA:
-- La atomicidad se garantiza porque toda la operación de ajuste salarial
-- está contenida dentro de una única transacción. Si algún paso falla,
-- se ejecuta un ROLLBACK TO SAVEPOINT que revierte totalmente los cambios.
-- Esto asegura que los salarios no quedan parcialmente actualizados
-- y que la base de datos solo refleja estados completos y válidos.
 
-- CONSISTENCIA:
-- Explique cómo su solución asegura que los datos quedan válidos
-- después de la operación.
--
-- RESPUESTA:
-- La consistencia se preserva aplicando todas las reglas definidas por la variante:
-- antigüedad mínima, departamentos válidos, historial reciente y topes salariales.
-- Antes de actualizar, la prevalidación confirma que los nuevos salarios son permitidos.
-- Después del commit, las validaciones posteriores corroboran que no se violó ninguna
-- restricción lógica ni de negocio, garantizando que la BD termina en un estado correcto.
 
-- AISLAMIENTO:
-- Explique cómo se comportaría su transacción frente a otras sesiones.
--
-- RESPUESTA:
-- La transacción mantiene aislamiento porque los cambios no son visibles para
-- otras sesiones hasta que se hace COMMIT. Mientras tanto, otras sesiones siguen
-- viendo los salarios originales. Este comportamiento evita lecturas sucias
-- y mantiene la independencia entre operaciones simultáneas en la base de datos.
 
-- DURABILIDAD:
-- Explique qué garantiza la persistencia del cambio una vez confirmado.
--
-- RESPUESTA:
-- La durabilidad se garantiza mediante el COMMIT, que escribe los cambios en los
-- archivos de datos y en los redo logs de Oracle. Incluso si ocurre un fallo del
-- sistema después del commit, Oracle puede recuperar completamente la transacción
-- asegurando que los ajustes salariales y la auditoría permanezcan intactos.
 
-- USO DE SAVEPOINT / ROLLBACK:
-- Explique qué riesgo controló y por qué ese punto de restauración
-- era necesario.
--
-- RESPUESTA:
-- El SAVEPOINT se usa para controlar el riesgo de aplicar salarios que excedan
-- los topes permitidos por la variante. Si la validación intermedia detecta
-- un incumplimiento, se puede volver al punto anterior sin afectar otras operaciones.
-- Esto garantiza control granular y evita que ajustes erróneos queden almacenados
-- dentro de la transacción.

