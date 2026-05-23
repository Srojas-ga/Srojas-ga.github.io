-- ============================================================
-- 0. ENCABEZADO 
-- ============================================================
-- Integrante 1: Estefania Paredes C
-- Integrante 2: Santiago Rojas G
-- Curso: Bases de Datos 2
-- Fecha: 20/04/2026
-----------------------------------------------------------------

SET SERVEROUTPUT ON;

-- 1 — Funciones encadenadas

DECLARE
    vn_id_empleado   NUMBER := 1004;
    vv_quincena      VARCHAR2(20) := '2026-Q1-ENE';

    vv_nombre        empleados.nombre%TYPE;
    vn_salario       empleados.salario_base%TYPE;
    vv_tipo          empleados.tipo_contrato%TYPE;
    vd_fecha_ing     empleados.fecha_ingreso%TYPE;
    vv_sede          empleados.cod_sede%TYPE;

    vn_salario_q     NUMBER := 0;
    vn_recargos      NUMBER := 0;
    vn_bonificacion  NUMBER := 0;
    vn_antiguedad    NUMBER := 0;
    vn_sanciones     NUMBER := 0;

    vn_ret_serv      NUMBER;
    vn_rec_noct      NUMBER;
    vn_rec_dom       NUMBER;
    vn_rec_noct_dom  NUMBER;

    CURSOR c_horas IS
        SELECT tipo_hora, cantidad_horas
        FROM horas_trabajadas
        WHERE id_empleado = vn_id_empleado
        AND id_quincena = vv_quincena;

    vn_valor_hora NUMBER;

BEGIN
    SELECT nombre, salario_base, tipo_contrato, fecha_ingreso, cod_sede
    INTO vv_nombre, vn_salario, vv_tipo, vd_fecha_ing, vv_sede
    FROM empleados
    WHERE id_empleado = vn_id_empleado;

    SELECT valor_numerico INTO vn_ret_serv FROM parametros WHERE cod_parametro = 'RET_SERVICIOS';
    SELECT valor_numerico INTO vn_rec_noct FROM parametros WHERE cod_parametro = 'RECARGO_NOCTURNO';
    SELECT valor_numerico INTO vn_rec_dom FROM parametros WHERE cod_parametro = 'RECARGO_DOMINICAL';
    SELECT valor_numerico INTO vn_rec_noct_dom FROM parametros WHERE cod_parametro = 'RECARGO_NOCT_DOM';

    IF vv_tipo = 'PLANTA' THEN
        vn_salario_q := vn_salario / 2;
        vn_valor_hora := vn_salario / 240;

    ELSIF vv_tipo = 'TEMPORAL' THEN
        SELECT NVL(SUM(cantidad_horas),0)
        INTO vn_salario_q
        FROM horas_trabajadas
        WHERE id_empleado = vn_id_empleado
        AND tipo_hora = 'NORMAL'
        AND id_quincena = vv_quincena;

        vn_salario_q := vn_salario_q * vn_salario;
        vn_valor_hora := vn_salario;

    ELSE 
        vn_salario_q := (vn_salario - (vn_salario * vn_ret_serv / 100)) / 2;
    END IF;

    IF vv_tipo <> 'SERVICIOS' THEN
        FOR r IN c_horas LOOP
            IF r.tipo_hora = 'NOCTURNA' THEN
                vn_recargos := vn_recargos + (r.cantidad_horas * vn_valor_hora * (vn_rec_noct/100));

            ELSIF r.tipo_hora = 'DOMINICAL' THEN
                vn_recargos := vn_recargos + (r.cantidad_horas * vn_valor_hora * (vn_rec_dom/100));

            ELSIF r.tipo_hora = 'NOCTURNA_DOM' THEN
                vn_recargos := vn_recargos + (r.cantidad_horas * vn_valor_hora * (vn_rec_noct_dom/100));
            END IF;
        END LOOP;
    END IF;

    vn_antiguedad := TRUNC(MONTHS_BETWEEN(SYSDATE, vd_fecha_ing) / 12);

    SELECT COUNT(*)
    INTO vn_sanciones
    FROM sanciones
    WHERE id_empleado = vn_id_empleado
    AND fecha_sancion >= ADD_MONTHS(SYSDATE, -6);

    IF vv_tipo <> 'SERVICIOS' AND vn_sanciones <= 2 THEN
        IF vn_antiguedad BETWEEN 3 AND 5 THEN
            vn_bonificacion := vn_salario_q * 0.03;

        ELSIF vn_antiguedad BETWEEN 6 AND 10 THEN
            vn_bonificacion := vn_salario_q * 0.06;

        ELSIF vn_antiguedad > 10 THEN
            vn_bonificacion := vn_salario_q * 0.10;
        END IF;
    END IF;

    DBMS_OUTPUT.PUT_LINE('=== LIQUIDACIÓN QUINCENAL ===');
    DBMS_OUTPUT.PUT_LINE('Empleado: ' || vv_nombre || ' (' || vn_id_empleado || ')');
    DBMS_OUTPUT.PUT_LINE('Sede: ' || vv_sede);
    DBMS_OUTPUT.PUT_LINE('Tipo contrato: ' || vv_tipo);
    DBMS_OUTPUT.PUT_LINE('Antigüedad: ' || vn_antiguedad || ' años');
    DBMS_OUTPUT.PUT_LINE('-----------------------------');
    DBMS_OUTPUT.PUT_LINE('Salario base Q: ' || TO_CHAR(vn_salario_q, '999,999,999.99'));
    DBMS_OUTPUT.PUT_LINE('Recargos: ' || TO_CHAR(vn_recargos, '999,999,999.99'));
    DBMS_OUTPUT.PUT_LINE('Bonificación: ' || TO_CHAR(vn_bonificacion, '999,999,999.99'));
    DBMS_OUTPUT.PUT_LINE('-----------------------------');
    DBMS_OUTPUT.PUT_LINE('SUBTOTAL: ' || TO_CHAR((vn_salario_q + vn_recargos + vn_bonificacion), '999,999,999.99'));

END;
/
--------------------------
-- 2 — Funciones encadenadas
--------------------------

--Salario Base

CREATE OR REPLACE FUNCTION fn_salario_base(
    p_id_empleado  IN NUMBER,
    p_id_quincena  IN VARCHAR2
) RETURN NUMBER
IS
    v_tipo    empleados.tipo_contrato%TYPE;
    v_salario empleados.salario_base%TYPE;
    v_result  NUMBER := 0;
    v_ret     NUMBER; -- ✅ MOVIDA AQUÍ
BEGIN
    SELECT tipo_contrato, salario_base
    INTO v_tipo, v_salario
    FROM empleados
    WHERE id_empleado = p_id_empleado;

    IF v_tipo = 'PLANTA' THEN
        v_result := v_salario / 2;

    ELSIF v_tipo = 'TEMPORAL' THEN
        SELECT NVL(SUM(cantidad_horas),0)
        INTO v_result
        FROM horas_trabajadas
        WHERE id_empleado = p_id_empleado
        AND id_quincena = p_id_quincena
        AND tipo_hora = 'NORMAL';

        v_result := v_result * v_salario;

    ELSIF v_tipo = 'SERVICIOS' THEN
        SELECT valor_numerico
        INTO v_ret
        FROM parametros
        WHERE cod_parametro = 'RET_SERVICIOS';

        v_result := (v_salario - (v_salario * v_ret / 100)) / 2;
    END IF;

    RETURN ROUND(v_result,2);

EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 0;
END;
/

--recargos

CREATE OR REPLACE FUNCTION fn_recargos (
    p_id_empleado  IN NUMBER,
    p_id_quincena  IN VARCHAR2
) RETURN NUMBER
IS
    v_tipo        empleados.tipo_contrato%TYPE;
    v_salario     empleados.salario_base%TYPE;
    v_valor_hora  NUMBER;
    v_total       NUMBER := 0;

    v_rec_noct NUMBER;
    v_rec_dom  NUMBER;
    v_rec_nd   NUMBER;

    CURSOR c_horas(p_id NUMBER, p_q VARCHAR2) IS
        SELECT tipo_hora, cantidad_horas
        FROM horas_trabajadas
        WHERE id_empleado = p_id
        AND id_quincena = p_q;

    v_tipo_hora   VARCHAR2(20);
    v_cantidad    NUMBER;

BEGIN
    SELECT tipo_contrato, salario_base
    INTO v_tipo, v_salario
    FROM empleados
    WHERE id_empleado = p_id_empleado;

    IF v_tipo = 'SERVICIOS' THEN
        RETURN 0;
    END IF;

    SELECT valor_numerico INTO v_rec_noct FROM parametros WHERE cod_parametro = 'RECARGO_NOCTURNO';
    SELECT valor_numerico INTO v_rec_dom  FROM parametros WHERE cod_parametro = 'RECARGO_DOMINICAL';
    SELECT valor_numerico INTO v_rec_nd   FROM parametros WHERE cod_parametro = 'RECARGO_NOCT_DOM';

IF v_tipo = 'PLANTA' THEN
    v_valor_hora := NVL(v_salario,0) / 240;
ELSE
    v_valor_hora := NVL(v_salario,0);
END IF;

    OPEN c_horas(p_id_empleado, p_id_quincena);
    LOOP
        FETCH c_horas INTO v_tipo_hora, v_cantidad;
        EXIT WHEN c_horas%NOTFOUND;

        IF v_tipo_hora = 'NOCTURNA' THEN
            v_total := v_total + (v_cantidad * v_valor_hora * (v_rec_noct/100));

        ELSIF v_tipo_hora = 'DOMINICAL' THEN
            v_total := v_total + (v_cantidad * v_valor_hora * (v_rec_dom/100));

        ELSIF v_tipo_hora = 'NOCTURNA_DOM' THEN
            v_total := v_total + (v_cantidad * v_valor_hora * (v_rec_nd/100));
        END IF;

    END LOOP;
    CLOSE c_horas;

    RETURN ROUND(v_total,2);

EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 0;
    WHEN OTHERS THEN RAISE;
END;
/

--Bonificacion

CREATE OR REPLACE FUNCTION fn_bonificacion (
    p_id_empleado IN NUMBER,
    p_id_quincena IN VARCHAR2   
) RETURN NUMBER
IS
    v_tipo       empleados.tipo_contrato%TYPE;
    v_fecha_ing  empleados.fecha_ingreso%TYPE;
    v_antig      NUMBER;
    v_sanciones  NUMBER;
    v_salario_q  NUMBER;
    v_bono       NUMBER := 0;
BEGIN
    SELECT tipo_contrato, fecha_ingreso
    INTO v_tipo, v_fecha_ing
    FROM empleados
    WHERE id_empleado = p_id_empleado;

    IF v_tipo = 'SERVICIOS' THEN
        RETURN 0;
    END IF;

    v_salario_q := fn_salario_base_q(p_id_empleado, p_id_quincena);
    v_antig     := TRUNC(MONTHS_BETWEEN(SYSDATE, v_fecha_ing) / 12);

    SELECT COUNT(*)
    INTO v_sanciones
    FROM sanciones
    WHERE id_empleado   = p_id_empleado
      AND fecha_sancion >= ADD_MONTHS(SYSDATE, -6);

    IF v_sanciones > 2 THEN   
        RETURN 0;
    END IF;

    IF v_antig BETWEEN 3 AND 5 THEN
        v_bono := v_salario_q * 0.03;
    ELSIF v_antig BETWEEN 6 AND 10 THEN
        v_bono := v_salario_q * 0.06;
    ELSIF v_antig > 10 THEN
        v_bono := v_salario_q * 0.10;
    END IF;

    RETURN ROUND(v_bono, 2);

EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 0;
END;
/

-- Salario Bruto
CREATE OR REPLACE FUNCTION fn_bruto (
    p_id_empleado  IN NUMBER,
    p_id_quincena  IN VARCHAR2
) RETURN NUMBER
IS
    v_salario_q    NUMBER;
    v_recargos     NUMBER;
    v_bonificacion NUMBER;

    v_aux          NUMBER := 0;
    v_bono_sede    NUMBER := 0;

    v_bruto        NUMBER;

    v_smlmv        NUMBER;
    v_aux_trans    NUMBER;
    v_bono_sma     NUMBER;

    v_salario_base NUMBER;
    v_sede         VARCHAR2(5);
    v_tipo         VARCHAR2(20);
    v_horas_norm   NUMBER := 0;
BEGIN
    SELECT salario_base, cod_sede, tipo_contrato
    INTO v_salario_base, v_sede, v_tipo
    FROM empleados
    WHERE id_empleado = p_id_empleado;

    SELECT valor_numerico INTO v_smlmv     FROM parametros WHERE cod_parametro = 'SMLMV';
    SELECT valor_numerico INTO v_aux_trans FROM parametros WHERE cod_parametro = 'AUX_TRANSPORTE';
    SELECT valor_numerico INTO v_bono_sma  FROM parametros WHERE cod_parametro = 'BONO_CLIMA_SMA';

    v_salario_q    := fn_salario_base_q(p_id_empleado, p_id_quincena);
    v_recargos     := fn_recargos(p_id_empleado, p_id_quincena);

    v_bonificacion := fn_bonificacion(p_id_empleado, p_id_quincena);

    IF v_tipo = 'PLANTA' THEN
        IF v_salario_base <= (2 * v_smlmv) THEN
            v_aux := v_aux_trans / 2;
        END IF;

    ELSIF v_tipo = 'TEMPORAL' THEN
        SELECT NVL(SUM(cantidad_horas),0)
        INTO v_horas_norm
        FROM horas_trabajadas
        WHERE id_empleado = p_id_empleado
        AND id_quincena = p_id_quincena
        AND tipo_hora = 'NORMAL';

        IF (v_salario_base * v_horas_norm * 2) <= (2 * v_smlmv) THEN
            v_aux := v_aux_trans / 2;
        END IF;
    END IF;

    IF v_sede = 'SMA' AND v_tipo <> 'SERVICIOS' THEN
        v_bono_sede := v_bono_sma;
    END IF;

    v_bruto := v_salario_q + v_recargos + v_bonificacion + v_aux + v_bono_sede;

    RETURN ROUND(v_bruto,2);

EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 0;
    WHEN OTHERS THEN RAISE;
END;
/

DECLARE
    vdo_resultado_fn     NUMBER;
    vdo_resultado_manual NUMBER := 1523958.37;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== VALIDACIÓN FN_BRUTO ===');
 
    SELECT fn_bruto(1001, '2026-Q1-ENE')
    INTO vdo_resultado_fn
    FROM dual;
 
    DBMS_OUTPUT.PUT_LINE('Resultado función : ' ||
        TO_CHAR(vdo_resultado_fn,'FM999,999,990.00'));
 
    DBMS_OUTPUT.PUT_LINE('Resultado manual  : ' ||
        TO_CHAR(vdo_resultado_manual,'FM999,999,990.00'));
 
END;
/

--3.Procedimiento con Excepciones

CREATE OR REPLACE PROCEDURE sp_liquidar_empleado (
    p_id_empleado IN NUMBER,
    p_id_quincena IN VARCHAR2
)
IS
    v_estado       empleados.estado%TYPE;
    v_sede         empleados.cod_sede%TYPE;
    v_tipo         empleados.tipo_contrato%TYPE;
    v_acepta_vol   empleados.acepta_aporte_vol%TYPE;

    v_bruto        NUMBER;
    v_salario_q    NUMBER;

    v_salud        NUMBER := 0;
    v_pension      NUMBER := 0;
    v_fondo        NUMBER := 0;
    v_embargo      NUMBER := 0;
    v_libranzas    NUMBER := 0;
    v_aporte_vol   NUMBER := 0;
    v_deducciones  NUMBER := 0;
    v_neto         NUMBER := 0;

    v_pct_salud    NUMBER;
    v_pct_pension  NUMBER;
    v_pct_fondo    NUMBER;
    v_umbral_fondo NUMBER;
    v_smlmv        NUMBER;
    v_aporte_bog   NUMBER;

    v_base_embargo NUMBER;
    v_pct_embargo  NUMBER := 0;
    v_cnt_liq      NUMBER;
BEGIN
    -- Validación 1: empleado existe
    BEGIN
        SELECT estado, cod_sede, tipo_contrato, acepta_aporte_vol
        INTO v_estado, v_sede, v_tipo, v_acepta_vol
        FROM empleados
        WHERE id_empleado = p_id_empleado;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Empleado no encontrado: ' || p_id_empleado);
    END;

    -- Validación 2: empleado activo
    IF v_estado <> 'ACTIVO' THEN
        RAISE_APPLICATION_ERROR(-20002,
            'Empleado no activo: estado = ' || v_estado);
    END IF;

    -- Validación 3: no liquidar dos veces
    SELECT COUNT(*)
    INTO v_cnt_liq
    FROM liquidacion
    WHERE id_empleado = p_id_empleado
      AND id_quincena = p_id_quincena;

    IF v_cnt_liq > 0 THEN
        RAISE_APPLICATION_ERROR(-20003,
            'Liquidación ya existe para empleado ' || p_id_empleado ||
            ' quincena ' || p_id_quincena);
    END IF;

    -- Calcular bruto usando funciones del Punto 2
    v_salario_q := fn_salario_base_q(p_id_empleado, p_id_quincena);
    v_bruto     := fn_bruto(p_id_empleado, p_id_quincena);

    -- Leer parámetros para deducciones
    SELECT valor_numerico INTO v_pct_salud    FROM parametros WHERE cod_parametro = 'PCT_SALUD';
    SELECT valor_numerico INTO v_pct_pension  FROM parametros WHERE cod_parametro = 'PCT_PENSION';
    SELECT valor_numerico INTO v_pct_fondo    FROM parametros WHERE cod_parametro = 'PCT_FONDO_SOLIDARIDAD';
    SELECT valor_numerico INTO v_umbral_fondo FROM parametros WHERE cod_parametro = 'UMBRAL_FONDO_SMLMV';
    SELECT valor_numerico INTO v_smlmv        FROM parametros WHERE cod_parametro = 'SMLMV';
    SELECT valor_numerico INTO v_aporte_bog   FROM parametros WHERE cod_parametro = 'APORTE_VOL_BOG';

    -- Regla 7: Deducciones
    -- 1. Salud
    v_salud   := ROUND(v_bruto * v_pct_salud   / 100, 2);
    -- 2. Pensión
    v_pension := ROUND(v_bruto * v_pct_pension / 100, 2);

    -- 3. Fondo de solidaridad: solo si bruto*2 > umbral*SMLMV
    IF (v_bruto * 2) > (v_umbral_fondo * v_smlmv) THEN
        v_fondo := ROUND(v_bruto * v_pct_fondo / 100, 2);
    END IF;

    -- 4. Embargo
    v_base_embargo := v_bruto - v_salud - v_pension - v_fondo;
    SELECT NVL(SUM(porcentaje), 0)
    INTO v_pct_embargo
    FROM embargos
    WHERE id_empleado = p_id_empleado
      AND estado = 'ACTIVO';

    v_embargo := ROUND(v_base_embargo * v_pct_embargo / 100, 2);

    -- 5. Libranzas
    SELECT NVL(SUM(cuota_mensual), 0) / 2
    INTO v_libranzas
    FROM libranzas
    WHERE id_empleado = p_id_empleado
      AND estado = 'ACTIVA';

    v_libranzas := ROUND(v_libranzas, 2);

    -- 6. Aporte voluntario BOG
    IF v_sede = 'BOG' AND v_acepta_vol = 'S' THEN
        v_aporte_vol := v_aporte_bog;
    END IF;

    v_deducciones := v_salud + v_pension + v_fondo + v_embargo + v_libranzas + v_aporte_vol;
    v_neto        := v_bruto - v_deducciones;

    -- Regla 8: Neto negativo
    IF v_neto < 0 THEN
        v_embargo     := 0;
        v_deducciones := v_salud + v_pension + v_fondo + v_embargo + v_libranzas + v_aporte_vol;
        v_neto        := v_bruto - v_deducciones;

        IF v_neto < 0 THEN
            v_libranzas   := 0;
            v_deducciones := v_salud + v_pension + v_fondo + v_embargo + v_libranzas + v_aporte_vol;
            v_neto        := v_bruto - v_deducciones;
        END IF;
    END IF;

    -- Insertar en LIQUIDACION
    INSERT INTO liquidacion (
        id_liquidacion,
        id_empleado,
        id_quincena,
        salario_base_q,
        total_bruto,
        salud,
        pension,
        fondo_solidaridad,
        embargo,
        libranzas,
        aporte_voluntario,
        total_deducciones,
        total_neto
    ) VALUES (
        seq_liquidacion.NEXTVAL,
        p_id_empleado,
        p_id_quincena,
        v_salario_q,
        v_bruto,
        v_salud,
        v_pension,
        v_fondo,
        v_embargo,
        v_libranzas,
        v_aporte_vol,
        v_deducciones,
        v_neto
    );

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_liquidar_empleado;
/

--5 Compound Trigger

CREATE OR REPLACE TRIGGER trg_liquidacion_ct
FOR INSERT ON liquidacion
COMPOUND TRIGGER

    g_ajuste_row BOOLEAN := FALSE;

BEFORE EACH ROW IS
BEGIN
    g_ajuste_row := FALSE;

    -- Validar salario base no negativo
    IF :NEW.salario_base_q < 0 THEN
        RAISE_APPLICATION_ERROR(-20010,
            'Salario base no puede ser negativo');
    END IF;

    -- Manejo de neto negativo
    IF :NEW.total_neto < 0 THEN
        g_ajuste_row := TRUE;

        -- Paso 1: quitar embargo
        :NEW.embargo := 0;
        :NEW.total_deducciones :=
              NVL(:NEW.salud, 0)
            + NVL(:NEW.pension, 0)
            + NVL(:NEW.fondo_solidaridad, 0)
            + NVL(:NEW.embargo, 0)
            + NVL(:NEW.libranzas, 0)
            + NVL(:NEW.aporte_voluntario, 0);
        :NEW.total_neto := :NEW.total_bruto - :NEW.total_deducciones;

        -- Paso 2: si sigue negativo, quitar libranzas
        IF :NEW.total_neto < 0 THEN
            :NEW.libranzas := 0;
            :NEW.total_deducciones :=
                  NVL(:NEW.salud, 0)
                + NVL(:NEW.pension, 0)
                + NVL(:NEW.fondo_solidaridad, 0)
                + NVL(:NEW.embargo, 0)
                + NVL(:NEW.libranzas, 0)
                + NVL(:NEW.aporte_voluntario, 0);
            :NEW.total_neto := :NEW.total_bruto - :NEW.total_deducciones;
        END IF;
    END IF;

END BEFORE EACH ROW;

AFTER EACH ROW IS
BEGIN
    -- Log si hubo ajuste
    IF g_ajuste_row THEN
        INSERT INTO log_nomina (id_log, fecha_log, operacion, detalle)
        VALUES (
            seq_log.NEXTVAL,
            SYSTIMESTAMP,
            'ALERTA_NETO_NEGATIVO',
            'Empleado ' || :NEW.id_empleado ||
            ' ajustado en quincena ' || :NEW.id_quincena
        );
    END IF;

    -- Actualizar saldo de libranzas
    UPDATE libranzas
    SET saldo_pendiente = saldo_pendiente - NVL(:NEW.libranzas, 0)
    WHERE id_empleado = :NEW.id_empleado
      AND estado      = 'ACTIVA'
      AND ROWNUM      = 1;

    -- Marcar libranzas pagadas
    UPDATE libranzas
    SET estado = 'PAGADA'
    WHERE id_empleado     = :NEW.id_empleado
      AND saldo_pendiente <= 0;

END AFTER EACH ROW;

AFTER STATEMENT IS
BEGIN
    INSERT INTO log_nomina (id_log, fecha_log, operacion, detalle)
    VALUES (
        seq_log.NEXTVAL,
        SYSTIMESTAMP,
        'INSERT_LIQUIDACION',
        'Lote procesado a las ' || TO_CHAR(SYSTIMESTAMP, 'HH24:MI:SS.FF3')
    );
END AFTER STATEMENT;

END trg_liquidacion_ct;
/


CREATE OR REPLACE PACKAGE pkg_nomina IS

    -- Colección de IDs
    TYPE t_ids IS TABLE OF empleados.id_empleado%TYPE;

    -- Registro de liquidación
    TYPE t_liq_rec IS RECORD (
        id_empleado         NUMBER,
        id_quincena         VARCHAR2(20),
        salario_base_q      NUMBER,
        total_bruto         NUMBER,
        total_deducciones   NUMBER,
        total_neto          NUMBER,
        embargo             NUMBER,
        libranzas           NUMBER
    );

    -- Lista de liquidaciones
    TYPE t_lista_liq IS TABLE OF t_liq_rec;

    -- 🔹 PUNTO 6
    PROCEDURE sp_liquidar_quincena(p_id_quincena VARCHAR2);

    -- 🔹 PUNTO 7
    FUNCTION fn_reporte_nomina(
        p_cod_sede        VARCHAR2 DEFAULT NULL,
        p_tipo_contrato   VARCHAR2 DEFAULT NULL
    ) RETURN t_lista_liq PIPELINED;

END pkg_nomina;
/

CREATE OR REPLACE PACKAGE BODY pkg_nomina IS

-- PUNTO 6: PROCEDIMIENTO MASIVO

PROCEDURE sp_liquidar_quincena(p_id_quincena VARCHAR2)
IS
    v_ids   t_ids;
    v_liq   t_lista_liq := t_lista_liq();

    v_salario_q     NUMBER;
    v_bruto         NUMBER;
    v_deducciones   NUMBER;
    v_neto          NUMBER;

    v_ok    NUMBER := 0;
    v_error NUMBER := 0;

BEGIN

    SELECT id_empleado
    BULK COLLECT INTO v_ids
    FROM empleados e
    WHERE e.estado = 'ACTIVO'
    AND NOT EXISTS (
        SELECT 1
        FROM liquidacion l
        WHERE l.id_empleado = e.id_empleado
        AND l.id_quincena = p_id_quincena
    );

    FOR i IN 1 .. v_ids.COUNT LOOP
        BEGIN
            v_salario_q := fn_salario_base_q(v_ids(i), p_id_quincena);
            v_bruto     := fn_bruto(v_ids(i), p_id_quincena);

            v_deducciones := (v_bruto * 0.04) + (v_bruto * 0.04);
            v_neto := v_bruto - v_deducciones;

            v_liq.EXTEND;
            v_liq(v_liq.LAST) := t_liq_rec(
                v_ids(i),
                p_id_quincena,
                v_salario_q,
                v_bruto,
                v_deducciones,
                v_neto,
                0,
                0
            );

        EXCEPTION
            WHEN OTHERS THEN
                v_error := v_error + 1;
        END;
    END LOOP;

    BEGIN
        FORALL i IN 1 .. v_liq.COUNT SAVE EXCEPTIONS
            INSERT INTO liquidacion (
                id_liquidacion,
                id_empleado,
                id_quincena,
                salario_base_q,
                total_bruto,
                total_deducciones,
                total_neto,
                embargo,
                libranzas
            )
            VALUES (
                seq_liquidacion.NEXTVAL,
                v_liq(i).id_empleado,
                v_liq(i).id_quincena,
                v_liq(i).salario_base_q,
                v_liq(i).total_bruto,
                v_liq(i).total_deducciones,
                v_liq(i).total_neto,
                v_liq(i).embargo,
                v_liq(i).libranzas
            );

        v_ok := v_liq.COUNT;

    EXCEPTION
        WHEN OTHERS THEN
            -- 🔴 CORRECCIÓN AQUÍ
            v_error := SQL%BULK_EXCEPTIONS.COUNT;
            v_ok := v_liq.COUNT - v_error;
    END;

    DBMS_OUTPUT.PUT_LINE(
        'Procesados OK: ' || v_ok ||
        ' | Errores: ' || v_error
    );

END sp_liquidar_quincena;

-- =========================================================
-- 🔹 PUNTO 7: PIPELINED FUNCTION
-- =========================================================
FUNCTION fn_reporte_nomina(
    p_cod_sede        VARCHAR2 DEFAULT NULL,
    p_tipo_contrato   VARCHAR2 DEFAULT NULL
) RETURN t_lista_liq PIPELINED
IS
    v_sql   VARCHAR2(4000);
    v_cur   SYS_REFCURSOR;
    v_rec   t_liq_rec;
BEGIN

    v_sql := '
        SELECT 
            l.id_empleado,
            l.id_quincena,
            l.salario_base_q,
            l.total_bruto,
            l.total_deducciones,
            l.total_neto,
            l.embargo,
            l.libranzas
        FROM liquidacion l
        JOIN empleados e ON l.id_empleado = e.id_empleado
        WHERE 1=1
    ';

    IF p_cod_sede IS NOT NULL THEN
        v_sql := v_sql || ' AND e.cod_sede = :sede';
    END IF;

    IF p_tipo_contrato IS NOT NULL THEN
        v_sql := v_sql || ' AND e.tipo_contrato = :tipo';
    END IF;

    IF p_cod_sede IS NOT NULL AND p_tipo_contrato IS NOT NULL THEN
        OPEN v_cur FOR v_sql USING p_cod_sede, p_tipo_contrato;

    ELSIF p_cod_sede IS NOT NULL THEN
        OPEN v_cur FOR v_sql USING p_cod_sede;

    ELSIF p_tipo_contrato IS NOT NULL THEN
        OPEN v_cur FOR v_sql USING p_tipo_contrato;

    ELSE
        OPEN v_cur FOR v_sql;
    END IF;

    LOOP
        FETCH v_cur INTO v_rec;
        EXIT WHEN v_cur%NOTFOUND;
        PIPE ROW(v_rec);
    END LOOP;

    CLOSE v_cur;

    RETURN;

EXCEPTION
    WHEN OTHERS THEN
        IF v_cur%ISOPEN THEN
            CLOSE v_cur;
        END IF;
        RAISE;

END fn_reporte_nomina;

END pkg_nomina;
/

-- Este fue un intento de terminar el segundo taller, fue algo complicado ya que tocaba seguir un orden especifico para poder hacer las cosas bien
--Lastimosamente el intento no se logro completar ya que se tuvo problemas al momento de realizar el punto 4 que era de cierta manera el punto mas imporatne,
--ya que era la comprobacion de todo junto pero siempre teniamos un error al momento de correrlo.




