-- =====================================================================================
-- Recurso finalizado (INDIFIMA) y estado de cola de las OT de BC (creadas en BC o migradas),
-- recalculados desde la cola de fábrica de Oracle. SOLO LECTURA.
--
-- Origen: bloque PL/SQL de Andrés Holguín (01-10-2026), pasado a una sola SELECT para poder
-- exportar el resultado a Excel desde SQL Developer / Toad. Compatible con Oracle anterior
-- a 11.2 (sin LISTAGG: concatena con XMLAGG).
--
-- Recurso finalizado: misma regla que PRODUCCION.T_AUS_PRD_MAQURUTA. Por cada máquina de la
-- ruta en estado ESTAFIPR (terminada), una letra por tipo: C cortadora, L laminadora,
-- Q laqueadora, I impresora, M montadora, B bolsero. Si la ruta tiene más de una máquina de
-- ese tipo, la letra lleva "n/m" (n = posición entre las de su tipo, m = cuántas hay).
-- Sin repetir códigos. Diferencia con el trigger: se ordena por CONTADOR (orden de la ruta),
-- porque el momento en que terminó cada máquina no queda guardado (FEC_MODI cambia después).
--
-- Estado de cola, con los códigos que espera fncCreaCabeceraOP:
--   '1'    la OT está en la cola (PRODUCCION.PRD_CABEOTRE)
--   '2'    tiene ruta pero ya no está en la cola y no está cerrada
--          (es lo que manda T_BDR_PRD_CABEOTRE al sacarla de la cola)
--   vacío  cerrada: Oracle no manda nada al sacarla, el report no debe tocar el estado
--
-- Salen las OT de BC que están en la cola o tienen ruta (actual o histórico).
-- Columnas 1-4: entrada del report de GRX_Enteco_Fix. Columnas 5-6: solo para revisar.
-- RECURSO_FINALIZADO vacío = ninguna máquina terminada: el report no debe tocar el recurso.
-- =====================================================================================
WITH
PARAM AS (
   SELECT V.VALOR ESTAFIPR
     FROM GENERAL.VARIABLES V
    WHERE V.VARIABLE = 'ESTAFIPR'
),
OT AS (                                   -- OT de BC (Pharma 10, Manviel 05), una sola lectura por DG4
   SELECT /*+ MATERIALIZE */
          A.EMPRESA, A.NUMERO, A.SITUACIO, A.INDIFIMA
     FROM FICHTECN.NAV_FIC_CABEOTRE A
),
RUTA AS (                                 -- ruta actual + histórico, sin duplicar contadores
   SELECT M.EMPRESA, M.NUMEOTRE, M.CONTADOR, M.MAQUCODI, M.ESTADO
     FROM PRODUCCION.PRD_MAQURUTA M
    WHERE NOT EXISTS (SELECT 1
                        FROM PRODUCCION.PRD_HMAQURUT H
                       WHERE H.EMPRESA  = M.EMPRESA
                         AND H.NUMEOTRE = M.NUMEOTRE
                         AND H.CONTADOR = M.CONTADOR)
   UNION ALL
   SELECT H.EMPRESA, H.NUMEOTRE, H.CONTADOR, H.MAQUCODI, H.ESTADO
     FROM PRODUCCION.PRD_HMAQURUT H
),
RUTA_OT AS (
   SELECT R.EMPRESA, R.NUMEOTRE, R.CONTADOR, R.ESTADO,
          -- tipo para contar máquinas similares, como cContRere: primera palabra con su
          -- espacio ('IMPRESORA ') o el código entero si no tiene espacio
          NVL(SUBSTR(R.MAQUCODI, 1, INSTR(R.MAQUCODI, ' ')), R.MAQUCODI) TIPO,
          CASE
             WHEN INSTR(R.MAQUCODI, 'CORTADORA')  > 0 THEN 'C'
             WHEN INSTR(R.MAQUCODI, 'LAMINADORA') > 0 THEN 'L'
             WHEN INSTR(R.MAQUCODI, 'LAQUEADORA') > 0 THEN 'Q'
             WHEN INSTR(R.MAQUCODI, 'IMPRESORA')  > 0 THEN 'I'
             WHEN INSTR(R.MAQUCODI, 'MONTADORA')  > 0 THEN 'M'
             WHEN INSTR(R.MAQUCODI, 'BOLSERO')    > 0 THEN 'B'
          END LETRA
     FROM RUTA R
     JOIN OT ON OT.EMPRESA = R.EMPRESA AND OT.NUMERO = R.NUMEOTRE
),
CONTADA AS (
   SELECT RO.EMPRESA, RO.NUMEOTRE, RO.CONTADOR, RO.ESTADO, RO.LETRA,
          COUNT(*) OVER (PARTITION BY RO.EMPRESA, RO.NUMEOTRE, RO.TIPO)                     N_TIPO,
          RANK()   OVER (PARTITION BY RO.EMPRESA, RO.NUMEOTRE, RO.TIPO ORDER BY RO.CONTADOR) POS_TIPO
     FROM RUTA_OT RO
),
CODIGOS AS (
   SELECT C.EMPRESA, C.NUMEOTRE, C.CONTADOR,
          CASE WHEN C.N_TIPO = 1 THEN C.LETRA
               ELSE C.LETRA || C.POS_TIPO || '/' || C.N_TIPO
          END CODIGO
     FROM CONTADA C
     JOIN PARAM P ON C.ESTADO = P.ESTAFIPR
    WHERE C.LETRA IS NOT NULL
),
UNICOS AS (
   SELECT K.EMPRESA, K.NUMEOTRE, K.CONTADOR, K.CODIGO,
          ROW_NUMBER() OVER (PARTITION BY K.EMPRESA, K.NUMEOTRE, K.CODIGO ORDER BY K.CONTADOR) RN
     FROM CODIGOS K
),
RECURSO AS (                              -- sin LISTAGG: esta versión de Oracle no lo tiene
   SELECT U.EMPRESA, U.NUMEOTRE,
          XMLAGG(XMLELEMENT(E, U.CODIGO) ORDER BY U.CONTADOR).EXTRACT('//text()').getStringVal() INDIFIMA
     FROM UNICOS U
    WHERE U.RN = 1
    GROUP BY U.EMPRESA, U.NUMEOTRE
),
COLA AS (
   SELECT DISTINCT Q.EMPRESA, Q.NUMEOTRE
     FROM PRODUCCION.PRD_CABEOTRE Q
     JOIN OT ON OT.EMPRESA = Q.EMPRESA AND OT.NUMERO = Q.NUMEOTRE
)
SELECT OT.EMPRESA                                  EMPRESA,
       TO_CHAR(OT.NUMERO)                          NUMERO,
       RC.INDIFIMA                                 RECURSO_FINALIZADO,
       CASE
          WHEN CL.NUMEOTRE IS NOT NULL       THEN '1'
          WHEN NVL(OT.SITUACIO, ' ') <> 'C'  THEN '2'
       END                                         ESTADO_COLA,
       OT.SITUACIO                                 SITUACION_BC,       -- A abierta, C cerrada
       OT.INDIFIMA                                 RECURSO_ACTUAL_BC   -- lo que tiene hoy la OT en BC
  FROM OT
  LEFT JOIN RECURSO RC ON RC.EMPRESA = OT.EMPRESA AND RC.NUMEOTRE = OT.NUMERO
  LEFT JOIN COLA    CL ON CL.EMPRESA = OT.EMPRESA AND CL.NUMEOTRE = OT.NUMERO
 WHERE CL.NUMEOTRE IS NOT NULL
    OR EXISTS (SELECT 1
                 FROM RUTA_OT RO
                WHERE RO.EMPRESA  = OT.EMPRESA
                  AND RO.NUMEOTRE = OT.NUMERO)
 ORDER BY OT.EMPRESA, OT.NUMERO;
