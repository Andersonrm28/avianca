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
    SELECT A.ID AS AERONAVE_ID, C.ID AS CIUDAD_ID,  R.AEROPUERTO_DESTINO_ID AS AEROPUERTO_ID , P.Hora_Estimada_Llegada
        FROM AERONAVES A
        INNER JOIN PROGRAMACIONES P ON A.ID = P.AERONAVE_ID
        INNER JOIN VUELOS V ON V.ID = P.VUELO_ID
        INNER JOIN RUTAS R ON R.ID = V.Rutas_Id
        INNER JOIN AEROPUERTOS AP ON R.Aeropuerto_Destino_Id = AP.ID
        INNER JOIN CIUDADES C ON C.ID = AP.CIUDAD_ID
        ORDER BY P.ID ASC;


-- Punto 2
CREATE OR REPLACE PROCEDURE ASIGNAR_TRIPULACION IS
    V_AERONAVE_ID NUMBER;
    PROGRAMACION_ID NUMBER;
    ID_CIUDAD NUMBER;
    ID_AEROPUERTO NUMBER;
    HORA_ESTIMADA_SALIDA_VUELO TIMESTAMP;
    EMPLEADO_ID_PILOTO NUMBER;
    EMPLEADO_ID_AUXILIAR NUMBER;
    CARGO VARCHAR(255);
    CANTIDAD_HORAS_VUELO NUMBER;
    NUMERO_SILLAS NUMBER;
    
    --Creo un cursor que me traiga todos los pilotos que tengan 2 horas o menos
    --de descansos desde el ultimo vuelo y esten activos, limito el cursor a 2 registros
    CURSOR C_PILOTOS IS SELECT E.ID 
                        FROM EMPLEADOS E 
                        INNER JOIN PILOTOS P ON (E.ID = P.EMPLEADO_ID)
                        WHERE E.HORAS_DESCANSO_ULTIMO_VUELO <= 2 
                          AND ESTADO = 'Activo' 
                          AND UBICACION_ACTUAL_ID = ID_CIUDAD
                          AND ROWNUM <= 2;  
    NUMERO_AUXILIARES NUMBER;
    
    --Creo un curson que me traiga los empleados que tengan como cargo 'auxiliar'
    --que tengan 2 horas o menos de descanso desde el ultimo vuelo, esten activos,
    -- limito el cursor a una variable llamada NUMERO_AUXILIARES que luego le asignamos un valor dependiendo de la Regla de Negocio
    CURSOR C_AUXILIARES IS SELECT ID 
                    FROM EMPLEADOS
                    WHERE HORAS_DESCANSO_ULTIMO_VUELO <= 2 
                      AND ESTADO = 'Activo' 
                      AND UBICACION_ACTUAL_ID = ID_CIUDAD
                      AND CARGO = 'Auxiliar'
                      AND ROWNUM <= NUMERO_AUXILIARES;  
  BEGIN     
    
    --traigo el ID de la programacion que voy a programar para esto debe ser un ID que no tenga aeronave asignada, limito el query a un registro
     SELECT PG.ID, AE.ID, PG.HORA_ESTIMADA_SALIDA 
       INTO PROGRAMACION_ID, ID_AEROPUERTO, HORA_ESTIMADA_SALIDA_VUELO
            FROM AEROPUERTOS AE 
            INNER JOIN RUTAS RU ON AE.ID = RU.AEROPUERTO_ORIGEN_ID
            INNER JOIN VUELOS VL ON RU.ID = VL.RUTAS_ID
            INNER JOIN PROGRAMACIONES PG ON PG.VUELO_ID = VL.ID
            WHERE ROWNUM = 1 AND Pg.AERONAVE_ID IS NULL;

    
    --invoco la vista para saber la aeronave disponible y guardo el resultado en variables locales, 
    --filtro por el aeropuerto de donde sale la programacion que esto programando, y por los vuelos que llegan a ese aeropuerto con mas de 2 horas de anticipacion
    SELECT AERONAVE_ID, CIUDAD_ID INTO V_AERONAVE_ID, ID_CIUDAD FROM AERONAVE_DISPONIBLE
    WHERE Aeropuerto_Id = ID_AEROPUERTO 
      AND (Hora_Estimada_Llegada - HORA_ESTIMADA_SALIDA_VUELO)< '-00 02:00:00.0000000'
      AND ROWNUM = 1;
    
    
    --uso el cursor de pilotos para registrarlos como tripulacion de la programacion de vuelo
    OPEN C_PILOTOS;
      FETCH C_PILOTOS INTO EMPLEADO_ID_PILOTO;
      --siguiendo las indicaciones del taller para simplicidad del trabajo el primer piloto lo asigno como comandante
      --y el segundo piloto como primer oficial
      CARGO := 'Comandante';
      DBMS_OUTPUT.PUT_LINE('Se programo el Empleado: ' || EMPLEADO_ID_PILOTO || ', con el cargo de: ' || CARGO || ', en la programacion ID: ' || PROGRAMACION_ID);
      
      INSERT INTO PROGRAMACIONES_EMPLEADOS VALUES
       (PROG_EMPL_ID.nextval,PROGRAMACION_ID, EMPLEADO_ID_PILOTO,CARGO);
      
      FETCH C_PILOTOS INTO EMPLEADO_ID_PILOTO;
      CARGO := 'Primer Oficial';
      DBMS_OUTPUT.PUT_LINE('Se programo el Empleado: ' || EMPLEADO_ID_PILOTO || ', con el cargo de: ' || CARGO || ', en la programacion ID: ' || PROGRAMACION_ID);
      
      INSERT INTO PROGRAMACIONES_EMPLEADOS VALUES
       (PROG_EMPL_ID.nextval,PROGRAMACION_ID, EMPLEADO_ID_PILOTO,CARGO);
       
    CLOSE C_PILOTOS;
  
   --Busco cual es la capacidad total de numero de sillas del avion asignado al vuelo que estoy programando
   --para poder saber cuantos auxiliares de vuelo debo registrar en esta programacion de vuelo
    SELECT TP.SILLAS_CLASE_ECONOMICA + TP.SILLAS_CLASE_EJECUTIVA INTO NUMERO_SILLAS 
    FROM AERONAVES A INNER JOIN TIPOS_AERONAVES TP ON A.TIPO_AERONAVE_ID = TP.ID
    WHERE A.ID = V_AERONAVE_ID;
    
    
    --Realizo los condicionales para saber cuantos auxiliares de vuelo debo asignar a la programación
    --determino el numero de auxiliares y lo asigno a la variable NUMERO_AUXILIARES
    NUMERO_AUXILIARES := 0;
    IF NUMERO_SILLAS > 19 AND NUMERO_SILLAS < 50 THEN
      NUMERO_AUXILIARES := 1;
    ELSIF NUMERO_SILLAS >= 150 AND NUMERO_SILLAS <= 180 THEN
      NUMERO_AUXILIARES := 4;
    ELSIF NUMERO_SILLAS >= 50 AND NUMERO_SILLAS <= 853 THEN
      NUMERO_AUXILIARES := 2 + FLOOR((NUMERO_SILLAS - 50)/50);
    END IF;
    
    --Busco la cantidad promedio de horas de vuelo que tiene la ruta de la programacion que estoy programando
    SELECT R.CANTIDAD_PROMEDIO_HORAS INTO CANTIDAD_HORAS_VUELO 
    FROM RUTAS R
    INNER JOIN VUELOS V ON (V.RUTAS_ID = R.ID)
    INNER JOIN PROGRAMACIONES P ON (P.VUELO_ID = V.ID)
    WHERE P.ID = PROGRAMACION_ID;
    
    --realizo la condicion de regla de negocio que si las horas son mas de 6 debo llevar un remplazo para cada auxiliar
    IF CANTIDAD_HORAS_VUELO > 6 THEN
      NUMERO_AUXILIARES := NUMERO_AUXILIARES * 2;
    END IF;
    
    
    CARGO := 'Auxiliar';
    
    
    --utilizo el cursor de auxiliares y traigo todos los auxiliares necesarios limitando el query dependiendo de la variable NUMERO_AUXILIARES
    OPEN C_AUXILIARES;
    LOOP
    FETCH C_AUXILIARES INTO EMPLEADO_ID_AUXILIAR; 
      EXIT WHEN C_AUXILIARES%notfound;
      DBMS_OUTPUT.PUT_LINE('Se programo el Empleado: ' || EMPLEADO_ID_AUXILIAR || ', con el cargo de: ' || CARGO || ', en la programacion ID: ' || PROGRAMACION_ID);
      
      --inserto cada auxiliar encontrado en el query y lo asigno como tripulacion de esa programacion
      INSERT INTO PROGRAMACIONES_EMPLEADOS VALUES
       (PROG_EMPL_ID.nextval,PROGRAMACION_ID, EMPLEADO_ID_AUXILIAR,CARGO);
    END LOOP;
    CLOSE C_AUXILIARES;
  
    
    DBMS_OUTPUT.PUT_LINE('Programación ID:' || PROGRAMACION_ID || ', Ciudad de Salida ID: ' || ID_CIUDAD || ', Cantidad Horas de Vuelo: ' || CANTIDAD_HORAS_VUELO || ', Aeronave ID: ' || V_AERONAVE_ID || ', Numero de Sillas: ' || NUMERO_SILLAS || ', Cantidad de Auxiliares Programados: ' || NUMERO_AUXILIARES);
    
    --Actualizo el campo Aeronave_ID en la tabla de programaciones para indicar cual es el avion asignado y cambio el estado de programacion a 'Confirmado'
    UPDATE PROGRAMACIONES SET AERONAVE_ID = V_AERONAVE_ID , ESTADO_PROGRAMACION = 'Confirmado'
    WHERE ID = PROGRAMACION_ID;
    
  END;


--Punto 3
CREATE OR REPLACE PROCEDURE HACER_CHECKIN(ID_PROGRAMACION NUMBER, ID_PASAJERO NUMBER, TIPO_SILLA VARCHAR) IS
  CAPACIDAD_SILLA_ECONOMICA NUMBER;
  CAPACIDAD_SILLA_EJECUTIVA NUMBER;
  PASAJEROS_SILLA_ECONOMICA NUMBER;
  PASAJEROS_SILLA_EJECUTIVA NUMBER;
  BEGIN
  
    --Busco la capacidad de sillas del avion asignado a la programacion ID
    SELECT  TP.SILLAS_CLASE_ECONOMICA, TP.SILLAS_CLASE_EJECUTIVA INTO CAPACIDAD_SILLA_ECONOMICA, CAPACIDAD_SILLA_EJECUTIVA
    FROM PROGRAMACIONES P
    INNER JOIN AERONAVES A ON (P.AERONAVE_ID = A.ID)
    INNER JOIN TIPOS_AERONAVES TP ON (TP.ID = A.TIPO_AERONAVE_ID)
    WHERE P.ID = ID_PROGRAMACION;
    
    --Busco la cantidad disponible de sillas en esa programacion de vuelo
    SELECT CANTIDAD_PASAJEROS_TURISTA, CANTIDAD_PASAJEROS_EJECUTIVA INTO PASAJEROS_SILLA_ECONOMICA, PASAJEROS_SILLA_EJECUTIVA 
    FROM PROGRAMACIONES
    WHERE ID = ID_PROGRAMACION;
    
    
    IF TIPO_SILLA = 'Ejecutiva' THEN
      --Si la silla del pasajero es ejecutiva valido que hay espacio disponible en ese avion para ese tipo de silla
      IF CAPACIDAD_SILLA_EJECUTIVA > PASAJEROS_SILLA_EJECUTIVA THEN
      
        --Inserto el pasajero en la tabla check in
         INSERT INTO CHECKIN VALUES
           (CHECKIN_ID.nextval,
           (1+ABS(MOD(dbms_random.random,(CAPACIDAD_SILLA_ECONOMICA + CAPACIDAD_SILLA_EJECUTIVA)))), 
           ID_PASAJERO,
           ID_PROGRAMACION,
           ' ',
           102,
           ' ',
           ' ');
           
           --Actualizo la cantidad de pasajeros en clase ejecutiva a esa programacion de vuelo con la cantidad actual + 1
           UPDATE PROGRAMACIONES SET CANTIDAD_PASAJEROS_EJECUTIVA = CANTIDAD_PASAJEROS_EJECUTIVA + 1
           WHERE ID = ID_PROGRAMACION;
      END IF;
    ELSE
     --valido que hay espacio disponible en ese avion para ese tipo de silla
      IF CAPACIDAD_SILLA_ECONOMICA > PASAJEROS_SILLA_ECONOMICA THEN
      
        --Inserto el pasajero en la tabla check in
         INSERT INTO CHECKIN VALUES
           (CHECKIN_ID.nextval,
           (1+ABS(MOD(dbms_random.random,(CAPACIDAD_SILLA_ECONOMICA + CAPACIDAD_SILLA_EJECUTIVA)))), 
           ID_PASAJERO,
           ID_PROGRAMACION,
           ' ',
           102,
           ' ',
           ' ');
           
           --Actualizo la cantidad de pasajeros en clase economica a esa programacion de vuelo con la cantidad actual + 1
           UPDATE PROGRAMACIONES SET CANTIDAD_PASAJEROS_TURISTA = CANTIDAD_PASAJEROS_TURISTA + 1
           WHERE ID = ID_PROGRAMACION;
      END IF;
    END IF;
    
  END;

  
 
-- Punto 4
-- SELECCIONO DE LA TABLA PROGRAMACION EMPLEADOS TODOS LOS REGISTROS DADO UN ID DE PROGRAMACION DE VUELO
  
CREATE OR REPLACE VIEW TRIPULACION_DE_UN_VUELO AS
SELECT P.ID, PE.EMPLEADO_ID, E.NOMBRES, E.APELLIDOS, E.SEXO, PE. CARGO
FROM PROGRAMACIONES_EMPLEADOS PE 
INNER JOIN PROGRAMACIONES P ON P.ID = PE.PROGRAMACION_ID
INNER JOIN EMPLEADOS E ON E.ID = PE.EMPLEADO_ID;
 
  
  --PUNTO 5
  --Consulto los vuelos programados desde hoy hasta luego de 2 smanas ingresando aeropuerto origen, destino y el rango de la fecha.
CREATE OR REPLACE VIEW VUELOS_PROGRAMADOS_2SEMANAS AS
    SELECT V.DESCRIPCION, P.FECHA, P.HORA_ESTIMADA_SALIDA, R.AEROPUERTO_ORIGEN_ID, R.AEROPUERTO_DESTINO_ID
    FROM RUTAS R INNER JOIN VUELOS V ON R.ID = V.RUTAS_ID
                 INNER JOIN PROGRAMACIONES P ON V.ID = P.VUELO_ID;

	--   WHERE R.AEROPUERTO_ORIGEN_ID = 1002 AND R.AEROPUERTO_DESTINO_ID = 1014 AND P.FECHA BETWEEN SYSDATE AND SYSDATE + 14;
   
 --PUNTO 6 EXPLAIN PLAN DE LAS VISTAS
  EXPLAIN PLAN SET STATEMENT_ID = 'BAD1' FOR
  SELECT * FROM AERONAVE_DISPONIBLE;
  
  SELECT * FROM TABLE
  (DBMS_XPLAN.DISPLAY('PLAN_TABLE','BAD1','TYPICAL'));
  
  ---------
    EXPLAIN PLAN SET STATEMENT_ID = 'BAD2' FOR
  SELECT * FROM TRIPULACION_DE_UN_VUELO ;
  
    SELECT * FROM TABLE
  (DBMS_XPLAN.DISPLAY('PLAN_TABLE','BAD2','TYPICAL'));

  -------
  
     EXPLAIN PLAN SET STATEMENT_ID = 'BAD3' FOR
  SELECT * FROM VUELOS_PROGRAMADOS_2SEMANAS;
  
    SELECT * FROM TABLE
  (DBMS_XPLAN.DISPLAY('PLAN_TABLE','BAD3','TYPICAL'));




----------------------------------------------------------------------------------------------------
---------------	ESTOS UPDATES SON IMPORTANTES PARA QUE LOS DATOS QUE ESTAN EN LA BASE DE DATOS CUMPLAN LAS CONDICIONES DE LAS ANTERIORES VISTAS Y PROCEDIMIENTOS
--------------- DADO QUE LOS DATOS INGRESADOS EN EL TALLER 1 FUERON ALEATORIOS ESTOS DATOS NO TIENEN LOGICA
--Utilizar 3 aeropuertos no mas
UPDATE RUTAS SET AEROPUERTO_ORIGEN_ID = 1002, Aeropuerto_Destino_Id = 1014
WHERE ID < 110033;

UPDATE RUTAS SET AEROPUERTO_ORIGEN_ID = 1014, Aeropuerto_Destino_Id = 1069
WHERE ID > 110066;

UPDATE RUTAS SET AEROPUERTO_ORIGEN_ID = 1069, Aeropuerto_Destino_Id = 1002
WHERE ID BETWEEN 110033 AND 110066;


UPDATE PROGRAMACIONES SET AERONAVE_ID = NULL
WHERE ID < 500050;

UPDATE PROGRAMACIONES 
SET FECHA = TO_DATE( (TO_CHAR(SYSDATE,'YYYY-MM-DD') || ' 00:00:00'), 'YYYY-MM-DD HH24:MI:SS'),
Hora_Estimada_Salida = TO_DATE( (TO_CHAR(SYSDATE,'YYYY-MM-DD') || ' 12:00:00'), 'YYYY-MM-DD HH24:MI:SS'),
Hora_Estimada_Llegada = TO_DATE( (TO_CHAR(SYSDATE,'YYYY-MM-DD') || ' 16:00:00'), 'YYYY-MM-DD HH24:MI:SS'),
Estado_Programacion = 'Programado'
WHERE ID < 500050;

UPDATE PROGRAMACIONES 
SET FECHA = TO_DATE( (TO_CHAR(SYSDATE,'YYYY-MM-DD') || ' 00:00:00'), 'YYYY-MM-DD HH24:MI:SS'),
Hora_Estimada_Salida = TO_DATE( (TO_CHAR(SYSDATE,'YYYY-MM-DD') || ' 2:00:00'), 'YYYY-MM-DD HH24:MI:SS'),
Hora_Estimada_Llegada = TO_DATE( (TO_CHAR(SYSDATE,'YYYY-MM-DD') || ' 9:00:00'), 'YYYY-MM-DD HH24:MI:SS'),
Estado_Programacion = 'En vuelo'
WHERE ID BETWEEN 500050 AND 500150;


UPDATE EMPLEADOS SET Ubicacion_Actual_Id = 102
WHERE CARGO = 'Comandante';

UPDATE EMPLEADOS SET Ubicacion_Actual_Id = 114
WHERE CARGO = 'Primer Oficial';

UPDATE EMPLEADOS SET Ubicacion_Actual_Id = 165
WHERE ID < 200400;

UPDATE EMPLEADOS SET Ubicacion_Actual_Id = 102
WHERE ID BETWEEN 200400 AND 201200 AND CARGO = 'Auxiliar';

UPDATE EMPLEADOS SET Ubicacion_Actual_Id = 114
WHERE ID > 201200 AND CARGO = 'Auxiliar';

UPDATE EMPLEADOS SET HORAS_DESCANSO_ULTIMO_VUELO = 1
WHERE ID < 200400

UPDATE EMPLEADOS SET HORAS_DESCANSO_ULTIMO_VUELO = 2
WHERE ID BETWEEN 200400 AND 201800;

UPDATE EMPLEADOS SET HORAS_DESCANSO_ULTIMO_VUELO = 3
WHERE ID > 202000;


---- Punto 7 videos - lecturas
https://mega.nz/#!1y5QwQCb!WdmvcjGNwIh0PkBD5b7bgEc6v-fwI_1KbRe10F3MmxA

---- Punto 8 - video explicacion vistas procedimientos
https://mega.nz/#!5jpgzQzJ!p8Fo8g5tNFhhrbfKx27H9Vqm6bUBcmTZHTMjbToN6gs
