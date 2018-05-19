--------------------- TALLER 2 --------------------------
--A) CREAR CAMPO ESTADO_AERONAVE

ALTER TABLE AERONAVES
  ADD ESTADO_AERONAVE VARCHAR2(255) CHECK (ESTADO_AERONAVE IN ('Vuelo','Tierra','Mantenimiento', 'Reparación'));
  
UPDATE AERONAVES SET ESTADO_AERONAVE = 'Tierra';
  
alter table AERONAVES modify ESTADO_AERONAVE not null;
  
--B) CREAR CAMPO AEROPUETO_ACTUAL_ID

ALTER TABLE AERONAVES
  ADD AEROPUETO_ACTUAL_ID INTEGER;
  
  UPDATE AERONAVES SET AEROPUETO_ACTUAL_ID = 1002;
  
ALTER TABLE AERONAVES 
    ADD CONSTRAINT FK_AERONAVES_AERO_ACTUAL FOREIGN KEY (AEROPUETO_ACTUAL_ID) REFERENCES AEROPUERTOS(ID);
    
    
--C) CREAR CAMPO ESTADO_VUELO

ALTER TABLE PROGRAMACIONES
  ADD ESTADO_PROGRAMACION VARCHAR2(255) CHECK (ESTADO_PROGRAMACION IN ('En Vuelo','Cancelado','Retrasado','Confirmado','Abordando','Programado'));
  
  UPDATE PROGRAMACIONES SET ESTADO_PROGRAMACION = 'Confirmado';
  
  ALTER TABLE PROGRAMACIONES MODIFY ESTADO_PROGRAMACION not null;
  
  -- Punto 1   
 
CREATE OR REPLACE VIEW AERONAVE_DISPONIBLE AS
    --Selecciono El Id de la aeronave, y la ciudad en que sale la aeronave, estos datos me sirven para posteriormente invocar esta vista
    SELECT A.ID AS AERONAVE_ID, C.ID AS CIUDAD_ID FROM AERONAVES A
        INNER JOIN PROGRAMACIONES P ON A.ID = P.AERONAVE_ID
        INNER JOIN VUELOS V ON V.ID = P.VUELO_ID
        INNER JOIN RUTAS R ON R.ID = V.Rutas_Id
        INNER JOIN AEROPUERTOS AP ON R.Aeropuerto_Destino_Id = AP.ID
        INNER JOIN CIUDADES C ON C.ID = AP.CIUDAD_ID
        WHERE R.AEROPUERTO_DESTINO_ID = (
                        --Este subquery busca el aeropuerto de origen de la primera programacion que encuentre que no tenga avion asignado
                        --que su Aeronave_id sea Null, osea la programación de vuelo que vamos a programar
                        SELECT AE.ID FROM AEROPUERTOS AE 
                        INNER JOIN RUTAS RU ON AE.ID = RU.AEROPUERTO_ORIGEN_ID
                        INNER JOIN VUELOS VL ON RU.ID = VL.RUTAS_ID
                        INNER JOIN PROGRAMACIONES PG ON PG.VUELO_ID = VL.ID
                        WHERE ROWNUM = 1 AND Pg.Aeronave_Id IS NULL)
        -- Hago la resta de horas de estimada de llegada de otros vuelos a ese aeropuerto, con la estimada de salida de vuelo que estoy programando
        -- y traigo todos los registros de los aviones que llegen 2 horas antes
        AND CAST(P.Hora_Estimada_Llegada AS TIME) - CAST((
                        --Este subquery busca la hora estimada de salida de la primera programacion que encuentre que no tenga avion asignado
                        --que su Aeronave_id sea Null, osea programación de vuelo que vamos a programar
                        SELECT Pg.Hora_Estimada_Salida FROM PROGRAMACIONES PG
                        WHERE  ROWNUM = 1 AND Pg.Aeronave_Id IS NULL) AS TIME) < '-00 02:00:00.0000000'
       --Limito la busqueda de aviones que cumplan las condiciones al primero encontrado por simplicidad del ejercicio como dice en el taller
       AND ROWNUM = 1
       ORDER BY FECHA ASC;

  
 
-- Punto 4
-- Muestra el personal asignado a un vuelo desde que se ejecuta el query hasta dos semanas despues
  
CREATE OR REPLACE VIEW TRIPULACION_DE_UN_VUELO AS
SELECT P.ID, PE.EMPLEADO_ID, E.NOMBRES, E.APELLIDOS, E.SEXO, PE. CARGO
FROM PROGRAMACIONES_EMPLEADOS PE 
INNER JOIN PROGRAMACIONES P ON P.ID = PE.PROGRAMACION_ID
INNER JOIN EMPLEADOS E ON E.ID = PE.EMPLEADO_ID
WHERE P.ID = 500000; 
 
  
  --PUNTO 5
  --Consulto los vuelos programados desde hoy hasta luego de 2 smanas ingresando aeropuerto origen, destino y el rango de la fecha.
CREATE OR REPLACE VIEW VUELOS_PROGRAMADOS_2SEMANAS AS
    SELECT V.DESCRIPCION, P.FECHA, P.HORA_ESTIMADA_SALIDA
    FROM RUTAS R INNER JOIN VUELOS V ON R.ID = V.RUTAS_ID
                 INNER JOIN PROGRAMACIONES P ON V.ID = P.VUELO_ID
    WHERE R.AEROPUERTO_ORIGEN_ID = 1002 AND R.AEROPUERTO_DESTINO_ID = 1014 AND P.FECHA BETWEEN SYSDATE AND SYSDATE + 14;
   
--PUNTO 6
--EXPLAIN PLAN DEL PUNTO 5, EN DONDE PODEMOS VER LOS COSTOS DE LA CONSULTA
EXPLAIN PLAN SET STATEMENT_ID = 'BAD1' FOR
    SELECT V.DESCRIPCION, P.FECHA, P.HORA_ESTIMADA_SALIDA
    FROM RUTAS R INNER JOIN VUELOS V ON R.ID = V.RUTAS_ID
                 INNER JOIN PROGRAMACIONES P ON V.ID = P.VUELO_ID
    WHERE R.AEROPUERTO_ORIGEN_ID = 1002 AND R.AEROPUERTO_DESTINO_ID = 1014 AND P.FECHA BETWEEN SYSDATE AND SYSDATE + 14;

SELECT * FROM PLAN_TABLE;

SELECT * FROM TABLE
(DBMS_XPLAN.DISPLAY('PLAN_TABLE', 'BAD1', 'TYPICAL'));
