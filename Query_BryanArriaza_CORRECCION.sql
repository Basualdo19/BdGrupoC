/* Reiniciar base de laboratorio */
IF DB_ID('Academia2022') IS NOT NULL
BEGIN
    ALTER DATABASE Academia2022 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Academia2022;
END
GO

CREATE DATABASE Academia2022;
GO
USE Academia2022;
GO

/* Esquemas base */
CREATE SCHEMA Academico;  -- alumnos, cursos, carreras, matrículas
GO
CREATE SCHEMA Seguridad;  -- usuarios, roles, auditoría
GO
CREATE SCHEMA App;        -- vistas expuestas a la aplicación
GO
CREATE SCHEMA Lab;        -- objetos auxiliares de práctica
GO

--*Por qué:* Reiniciar garantiza *idempotencia*. 
--Separar en esquemas (Academico/Seguridad/App/Lab) aplica 
--*principio de responsabilidad* y prepara el terreno para DDL, DCL y transacciones.

------** CREAR TABLA CON PK,UNIQUE, CHECK Y DEFAULT**** ---

--Enunciado: *Enunciado.* Crea Academico.Alumnos con:  
--AlumnoID INT IDENTITY PK, Nombre NVARCHAR(60) NOT NULL, 
--Apellido NVARCHAR(60) NOT NULL, Email NVARCHAR(120) UNIQUE,
--Edad TINYINT CHECK (Edad >= 16), Activo BIT DEFAULT (1).

CREATE TABLE Academico.Alumnos(
AlumnoID INT IDENTITY (1,1) CONSTRAINT PK_Alumnos PRIMARY KEY,
AlumnoNombre NVARCHAR (60) NOT NULL,
AlumnoApellido NVARCHAR (60) NOT NULL,
AlumnoEmail NVARCHAR (120) NULL CONSTRAINT UQ_Alumnos_Email UNIQUE,
AlumnoEdad TINYINT NOT NULL CONSTRAINT CK_Alumno_Edad CHECK (AlumnoEdad>=16),
AlumnoActivo BIT NOT NULL CONSTRAINT DF_Alumno_Activo DEFAULT (1),
);

--**Enunciado.** Crea Academico.Carreras(Nombre UNIQUE)
--Y agregar CarreraID como FK **SET NULL** en Alumnos.
CREATE TABLE Academico.Carreras(
CarreraID INT IDENTITY (1,1) CONSTRAINT PK_Carreras PRIMARY KEY,
CarreraNombre NVARCHAR(80) NOT NULL CONSTRAINT UQ_Carreras_Nombre UNIQUE,
);
GO

ALTER TABLE Academico.Alumnos
ADD CarreraID INT NULL CONSTRAINT FK_Alumnos_Carreras
FOREIGN KEY (CarreraID) REFERENCES Academico.Carreras(CarreraID)
ON DELETE SET NULL ON UPDATE NO ACTION;

--**POR QUE:** EL CATALOGO NORMALIZA EL DOMINIO; SET NULL
--EVITA ELIMINAR ACCIDENTALENTE ALUMNOS AL BORRAR CARRERAS.



--**ENUNCIADO** Crea Academico.Cursos con Creditos BETWEEN 1 AND 10 Y NOMBRE UNIQUE.

CREATE TABLE Academico.Cursos(
CursoID INT IDENTITY(1,1) CONSTRAINT PK_Cursos PRIMARY KEY,
CursoNombre NVARCHAR(100) NOT NULL CONSTRAINT UQ_Cursos_Nombre UNIQUE,
CursoCreditos TINYINT NOT NULL CONSTRAINT CK_Cursos_Creditos CHECK (CursoCreditos BETWEEN 1 AND 10) 
);

--**POR QUE: Valida el **Rango** permitido de creditos y evita duplicidad de nombres.
--BETWEEN: En SQL sirve para filtrar valores dentro de un rango inclusivo 
--(incluye los extremos).
--Columna BETWEEN valor_inferior AND valor_superior equivalente = Columna>=valor_inferior AND columna <= valor_superior.
--Ejemplo: SELECT * FROM Products WHERE Precio BETWEEN 100 AND 200.

--**Enunciado** Crea Academico.Matriculas (AlumnoID, CursoID, Periodo CHAR(6))
-- Con PK compuesta y FKs **CASCADE**

CREATE TABLE Academico.Matriculas(
AlumnoID INT NOT NULL,
CursoID INT NOT NULL,
MatriculaPeriodo CHAR(6) NOT NULL CONSTRAINT CK_Matriculas_Periodo 
CHECK (MatriculaPeriodo LIKE '[12][0-9][S][12]'),
CONSTRAINT PK_Matriculas PRIMARY KEY (AlumnoID, CursoID, MatriculaPeriodo), 
CONSTRAINT FK_Matriculas_Alumnos FOREIGN KEY (AlumnoID) 
REFERENCES Academico.Alumnos(AlumnoID) ON DELETE CASCADE,
CONSTRAINT FK_Matriculas_Cursos FOREIGN KEY (CursoID)
REFERENCES Academico.Cursos(CursoID) ON DELETE CASCADE
);
GO

--Por que: La PK compuesta impide duplicados logicos (Mismo alumno, curso, periodo) y 
--las famosas FK's mantienen consistencia al borrar tabla Maestra --> Tabla hija.


--** Enunciado** Agrega NombreCompleto = Nombre + ' ' + Apellido PERSISTED en Alumnos y creale Indice

--*Enunciado.* Agrega NombreCompleto = Nombre + ' ' + Apellido PERSISTED en Alumnos y créale índice.

ALTER TABLE Academico.Alumnos
ADD NombreCompleto AS (AlumnoNombre + N' ' + AlumnoApellido) PERSISTED;

CREATE INDEX IX_Alumnos_NombreCompleto ON Academico.Alumnos(NombreCompleto);

--*Por qué:* PERSISTED permite *indexar* y evitar recomputo; acelera búsquedas por nombre completo.



--Enunciado.** Renombra Creditos de Cursos a CreditosECTS (sin recrear tabla).
--PARA hacer el cambio de la columna CursoCreditos a CursoCreditosECTS, es 
-- importante tomar en cuenta el CHECK
ALTER TABLE Academico.Cursos
DROP CONSTRAINT CK_Cursos_Creditos;
GO

--renombrar columna sin el check

EXEC sp_rename
	'Academico.Cursos.CursoCreditos', --OBJETO ACTUAL
	'CursoCreditosECTS', --NEW NAME
	'COLUMN';
GO

-- Volver el check 
ALTER TABLE Academico.Cursos
ADD CONSTRAINT CK_Cursos_Creditos CHECK (CursoCreditosECTS BETWEEN 1 AND 10);
GO


--**Enunciado.** Sobre Matriculas crea indice por (CursoID,Periodo) con INDEX
CREATE INDEX IX_Matriculas_Cursos_MatriculaPeriodo
ON Academico.Matriculas(CursoID, MatriculaPeriodo)
INCLUDE (AlumnoID);
GO


--**Enunciado.** Crea Academico.SeqCodigoCurso e insertalo como default en columna

CREATE SEQUENCE Academico.SeqCodigoCurso AS INT START WITH 1000 INCREMENT BY 1;
GO

ALTER TABLE Academico.Cursos
ADD CursoCodigo INT NOT NULL
	CONSTRAINT DF_Cursos_CursoCodigo DEFAULT (NEXT VALUE FOR Academico.SeqCodigoCurso);
GO
--*Por qué:* SEQUENCE es *reutilizable* y configurable (reinicio/salto), más flexible que 
--IDENTITY cuando la misma secuencia se usa en varias tablas.


--*Enunciado.* Extrae datos de contacto a Academico.Contactos(ContactoID PK, Email UNIQUE, Telefono). Agrega FK ContactoID en Alumnos.
 

CREATE TABLE Academico.Contactos(
ContactoID INT IDENTITY(1,1) CONSTRAINT PK_Contactos PRIMARY KEY,
Email      NVARCHAR(120) NULL CONSTRAINT UQ_Contactos_Email UNIQUE,
Telefono   VARCHAR(20)   NULL
);
GO
ALTER TABLE Academico.Alumnos
ADD ContactoID INT NULL
CONSTRAINT FK_Alumnos_Contactos
FOREIGN KEY (ContactoID) REFERENCES Academico.Contactos(ContactoID);

--*Por qué:* Reduce *redundancia* y centraliza contacto reutilizable (normalización 3FN).

-- ---> ***** TAREA PARA ESTUDIAR EVALUACION PARCIAL II <--- ***** --
--** Semana 7 — Diseño normalizado con DDL (aplicación práctica) **--
--** Ejercicio 7.1 — Separar datos de contacto **--
--Diseño normalizado con DDL - 
--** Ejercicio 7.1 — Separar datos de contacto **--


 --**Enunciado.** Extrae datos de contacto a `Academico.Contactos(ContactoID PK, Email UNIQUE, Telefono)`. Agrega FK `ContactoID` en `Alumnos`.

 --**Ejercicio 7.2 — Descomponer atributo multivalor (N:M) **--
--**Enunciado.** Agrega `Academico.AlumnoIdiomas(AlumnoID, Idioma, Nivel)` con PK compuesta.
CREATE TABLE Academico.AlumnoIdiomas(
  AlumnoID INT NOT NULL,
  Idioma   NVARCHAR(40) NOT NULL,
  Nivel    NVARCHAR(20) NOT NULL,
  CONSTRAINT PK_AlumnoIdiomas PRIMARY KEY (AlumnoID, Idioma),
  CONSTRAINT FK_AI_Alumno FOREIGN KEY (AlumnoID)
    REFERENCES Academico.Alumnos(AlumnoID) ON DELETE CASCADE
);
--**Por qué:** Un alumno puede tener **varios idiomas** (multivalor) → tabla propia N:M.
--** Ejercicio 7.3 — Evitar dependencia transitiva --**
--**Enunciado.** Mueve la descripción de carrera a su catálogo `Carreras`; `Alumnos` solo referencia `CarreraID`.
--**Solución:** *(Ya cumplido en 5.2; revalida con SELECTs)*  
--**Por qué:** Los atributos de la carrera **dependen** de `CarreraID`, no del alumno → referencia por FK.

--** Ejercicio 7.4 — Restricción de unicidad compuesta **--
--**Enunciado.** Evita que un alumno se matricule dos veces al mismo curso en el **mismo periodo** usando índice UNIQUE.
CREATE UNIQUE INDEX UQ_Matriculas_Alumno_Curso_Periodo
ON Academico.Matriculas(AlumnoID, CursoID, Cursos);
--**Por qué:** Aunque existe PK compuesta, este índice UNIQUE es equivalente y **mejora consulta** por ese patrón.




--** Semana 8 — Transacciones y ACID (COMMIT/ROLLBACK/aislamiento) sobre Academia2022 **--

--** Ejercicio 8.1 — Transacción controlada con validación **--
--**Enunciado.** Incrementa 3% `CreditosECTS` de cursos cuyo nombre contenga “Data”. Revierte si afectas > 10 filas.
BEGIN TRAN;
UPDATE c
SET CursoCreditosECTS = CursoCreditosECTS + CEILING(CursoCreditosECTS * 0.03)
FROM Academico.Cursos c
WHERE c.CursoNombre LIKE N'%Data%';  -- simulación
IF @@ROWCOUNT > 10
BEGIN
  ROLLBACK TRAN;  -- demasiados cursos afectados
END
ELSE
BEGIN
  COMMIT TRAN;
END
--**Por qué:** Evita cambios masivos involuntarios con **control de tamaño**.



--** Ejercicio 8.2 — `READ COMMITTED SNAPSHOT` para lectores sin bloqueos --**
--*Enunciado.** Habilita **RCSI** y prueba lecturas consistentes mientras otra transacción mantiene cambios abiertos.
USE master;
ALTER DATABASE Academia2022 SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
USE Academia2022;
/* Sesión A: BEGIN TRAN; UPDATE ... (no commit)
   Sesión B: SELECT ... (no se bloquea; ve versión anterior) */
--**Por qué:** Mejora **concurrencia** evitando bloqueos de lectura/escritura.


--** Ejercicio 8.3 — SAVEPOINT y ROLLBACK parcial **--
--**Enunciado.** Aumenta créditos de un conjunto, marca SAVEPOINT, aplica otra operación y revierte solo la segunda.
BEGIN TRAN;
UPDATE Academico.Cursos SET CursoCreditosECTS = CursoCreditosECTS + 1 WHERE CursoID <= 3;
SAVE TRAN punto1;
UPDATE Academico.Cursos SET CursoCreditosECTS = CursoCreditosECTS + 1 WHERE CursoID BETWEEN 4 AND 6;
-- reconsideramos:
ROLLBACK TRAN punto1;
COMMIT TRAN;
--**Por qué:** `SAVEPOINT` da **granularidad** para revertir parcialmente.


--** Ejercicio 8.4 — TRY…CATCH con seguridad de transacción** --
--**Enunciado.** Envolver operación y garantizar rollback ante error.
BEGIN TRY
  BEGIN TRAN;
  UPDATE Academico.Alumnos SET AlumnoEdad = AlumnoEdad + 1 WHERE AlumnoID <= 5;
  COMMIT TRAN;
END TRY
BEGIN CATCH
  IF XACT_STATE() <> 0 ROLLBACK TRAN;
  THROW;
END CATCH;
--**Por qué:** Previene transacciones abiertas y facilita **diagnóstico**.



--** Semana 9 — Arquitectura, catálogo del sistema y separación por capas **--
--**Ejercicio 9.1 — Objetos por esquema (catálogo) **--
--**Enunciado.** Lista cuántos objetos tiene cada esquema.
SELECT s.name AS Esquema, o.type, COUNT(*) AS Total
FROM sys.objects o
JOIN sys.schemas s ON s.schema_id = o.schema_id
GROUP BY s.name, o.type
ORDER BY s.name, o.type;
--**Por qué:** Conocer el **inventario** guía seguridad y mantenimiento.



--** Ejercicio 9.2 — Dependencias de objeto **--
--**Enunciado.** Muestra qué objetos dependen de `Academico.Matriculas`.
SELECT referencing_schema = SCHEMA_NAME(o.schema_id),
       referencing_object = o.name
FROM sys.sql_expression_dependencies d
JOIN sys.objects o ON d.referencing_id = o.object_id
WHERE d.referenced_id = OBJECT_ID('Academico.Matriculas');
--**Por qué:** Permite **análisis de impacto** antes de cambios DDL


--** Ejercicio 9.3 — Capa App con vistas seguras **--
--**Enunciado.** Crea `App.vw_ResumenAlumno` con info no sensible.
CREATE VIEW App.vw_ResumenAlumno
AS
SELECT a.AlumnoID, a.NombreCompleto, a.AlumnoEdad, a.CarreraID
FROM Academico.Alumnos a
WHERE a.AlumnoActivo = 1;
--**Por qué:** Aísla datos sensibles en tabla base; expone **superficie mínima** a apps..




--** Ejercicio 9.4 — Vista con `SCHEMABINDING` e índice --**
--**Enunciado.** Crear vista  agregada de matrículas por curso y **indexarla**.
CREATE VIEW App.vw_MatriculasPorCurso
WITH SCHEMABINDING
AS
SELECT m.CursoID, COUNT_BIG(*) AS Total
FROM Academico.Matriculas AS m
GROUP BY m.CursoID;
GO
CREATE UNIQUE CLUSTERED INDEX IX_vw_MatriculasPorCurso
ON App.vw_MatriculasPorCurso(CursoID);
--**Por qué:** `SCHEMABINDING` habilita indexación de vistas materiales, acelerando **agregados** frecuentes.



--** Semana 10 — Tipos de datos y objetos (JSON, temporal, SPARSE, computed) **--
--**Enunciado.** Crea `Lab.Eventos(Id IDENTITY PK, Payload NVARCHAR(MAX) CHECK ISJSON=1)`.
CREATE TABLE Lab.Eventos(
  Id INT IDENTITY(1,1) CONSTRAINT PK_Eventos PRIMARY KEY,
  Payload NVARCHAR(MAX) NOT NULL,
  CONSTRAINT CK_Eventos_Payload CHECK (ISJSON(Payload) = 1)
);
--**Por qué:** Permite flexibilidad manteniendo **validez mínima** del JSON.



--## Ejercicio 10.2 — Extraer propiedades de JSON
--**Enunciado.** Inserta un evento y lee `$.tipo` y `$.origen`.
INSERT INTO Lab.Eventos(Payload)
VALUES (N'{"tipo":"audit","origen":"app","entidad":"Alumno","id":1}');
SELECT JSON_VALUE(Payload, '$.tipo')   AS Tipo,
       JSON_VALUE(Payload, '$.origen') AS Origen
FROM Lab.Eventos;
--**Por qué:** `JSON_VALUE` facilita **lectura puntual** sin desnormalizar tablas principales.


--** Ejercicio 10.3 — Sparse columns para atributos opcionales **--
--**Enunciado.** Crea `Lab.AlumnoRedes(AlumnoID INT, Twitter NVARCHAR(50) SPARSE, Instagram NVARCHAR(50) SPARSE)`.
CREATE TABLE Lab.AlumnoRedes(
  AlumnoID INT NOT NULL,
  Twitter  NVARCHAR(50) SPARSE NULL,
  Instagram NVARCHAR(50) SPARSE NULL,
  CONSTRAINT FK_Redes_Alumno FOREIGN KEY (AlumnoID)
    REFERENCES Academico.Alumnos(AlumnoID) ON DELETE CASCADE
);
--**Por qué:** `SPARSE` ahorra espacio cuando abundan **NULLs**.



--** Ejercicio 10.4 — Tabla temporal del sistema (histórico) **--
--**Enunciado.** Convierte `Lab.Eventos` en **System‑Versioned** para historial automático.
ALTER TABLE Lab.Eventos
ADD ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START HIDDEN NOT NULL
    CONSTRAINT DF_Eventos_From DEFAULT SYSUTCDATETIME(),
    ValidTo   DATETIME2 GENERATED ALWAYS AS ROW END   HIDDEN NOT NULL
    CONSTRAINT DF_Eventos_To   DEFAULT CONVERT(DATETIME2,'9999-12-31'),
    PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo);
ALTER TABLE Lab.Eventos
SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = Lab.Eventos_Hist));
--**Por qué:** Guarda **versiones** automáticamente → auditoría y recuperación de estado.


--** Semana 11 — DCL I (Usuarios, Roles, Esquemas, Menor Privilegio) **--
--** Ejercicio 11.1 — Login + User con esquema por defecto **--
--**Enunciado.** Crea login/usuario `app_ro` con `DEFAULT_SCHEMA = App` y solo lectura.
USE master;
IF SUSER_ID('app_ro') IS NOT NULL DROP LOGIN app_ro;
CREATE LOGIN app_ro WITH PASSWORD = 'Str0ng_P@ssw0rd!';
GO
USE Academia2022;
IF USER_ID('app_ro') IS NOT NULL DROP USER app_ro;
CREATE USER app_ro FOR LOGIN app_ro WITH DEFAULT_SCHEMA = App;
EXEC sp_addrolemember N'db_datareader', N'app_ro';
--**Por qué:** Rol `db_datareader` otorga SELECT en la base; `DEFAULT_SCHEMA` simplifica nombres calificados




--** ## Ejercicio 11.2 — Rol personalizado con permisos a vistas
--**Enunciado.** Crea rol `rol_reportes` con `SELECT` sobre `App.vw_ResumenAlumno` y `App.vw_MatriculasPorCurso` y asócialo a `app_ro`. 
CREATE ROLE rol_reportes;
GRANT SELECT ON OBJECT::App.vw_ResumenAlumno    TO rol_reportes;
GRANT SELECT ON OBJECT::App.vw_MatriculasPorCurso TO rol_reportes;
EXEC sp_addrolemember 'rol_reportes', 'app_ro';
--**Por qué:** Agregar permisos a un **rol** centraliza la administración (asigna a muchos usuarios a la vez).



--** ## Ejercicio 11.3 — Denegar acceso directo a tablas base
--**Enunciado.** Deniega `SELECT` sobre `Academico.Alumnos` a `app_ro`.
DENY SELECT ON OBJECT::Academico.Alumnos TO app_ro;
--**Por qué:** Obliga a consumir datos vía **vistas de App**, reduciendo exposición.



--** ## Ejercicio 11.4 — Sinónimos para compatibilidad **--
--**Enunciado.** Crea sinónimo `dbo.Matriculas` → `Academico.Matriculas`
CREATE SYNONYM dbo.Matriculas FOR Academico.Matriculas;
--**Por qué:** Útil para **código legado** que asume esquema `dbo`.



--** Semana 12 — DCL II (GRANT/REVOKE/DENY, RLS, Auditoría) **--
--** Ejercicio 12.1 — GRANT por esquema **--
--**Enunciado.** Concede `SELECT` sobre todo el esquema `App` al rol `rol_reportes`.
GRANT SELECT ON SCHEMA::App TO rol_reportes;
--**Por qué:** Simplifica mantenimiento; no hace falta otorgar vista por vista.



--**## Ejercicio 12.2 — REVOKE fino **--
--**Enunciado.** Quita `SELECT` sobre `App.vw_ResumenAlumno` al rol (pero deja el del esquema).
REVOKE SELECT ON OBJECT::App.vw_ResumenAlumno FROM rol_reportes;
--**Por qué:** `REVOKE` retira concesiones; si sigue teniendo permiso por esquema, **prevalece** ese permiso (tenerlo en cuenta).




--## Ejercicio 12.3 — Row‑Level Security (RLS) básica **--
--**Enunciado.** Restringe a `app_ro` para ver solo alumnos **activos** en `App.vw_ResumenAlumno` aplicando filtro en tabla base.
--**Solución (mínima conceptual):**
CREATE SCHEMA Sec;
GO
CREATE FUNCTION Sec.fn_AlumnosActivos(@Activo bit)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS AllowRow WHERE @Activo = 1;
GO
CREATE SECURITY POLICY Sec.Policy_Alumnos
ADD FILTER PREDICATE Sec.fn_AlumnosActivos(Activo)
ON Academico.Alumnos
WITH (STATE = ON);
--**Por qué:** La política impone filtro en **tabla base**; vistas heredan la restricción.




--## Ejercicio 12.4 — Auditoría de permisos y autenticación fallida
--**Enunciado.** Configura auditoría de servidor+DB (ruta de archivos existente) para cambios de permisos e inicios de sesión fallidos.
-- A nivel servidor
CREATE SERVER AUDIT Audit_Academia
TO FILE (FILEPATH = 'C:\SQLAudit\');  -- Ajustar ruta
ALTER SERVER AUDIT Audit_Academia WITH (STATE = ON);
-- A nivel base
CREATE DATABASE AUDIT SPECIFICATION Audit_AcademiaDB
FOR SERVER AUDIT Audit_Academia
ADD (DATABASE_OBJECT_PERMISSION_CHANGE_GROUP),
ADD (FAILED_DATABASE_AUTHENTICATION_GROUP);
ALTER DATABASE AUDIT SPECIFICATION Audit_AcademiaDB WITH (STATE = ON);
--**Por qué:** La auditoría otorga **trazabilidad** regulatoria (quién cambió qué y cuándo).
---
--## Limpieza opcional
-- Desactivar temporal y RLS
IF OBJECT_ID('Lab.Eventos','U') IS NOT NULL
BEGIN
  ALTER TABLE Lab.Eventos SET (SYSTEM_VERSIONING = OFF);
  DROP TABLE Lab.Eventos, Lab.Eventos_Hist;
END
DROP SECURITY POLICY IF EXISTS Sec.Policy_Alumnos;
DROP FUNCTION IF EXISTS Sec.fn_AlumnosActivos;
DROP SCHEMA IF EXISTS Sec;


-- Quitar sinónimo y roles/usuarios (cuidado si se usan)
DROP SYNONYM IF EXISTS dbo.Matriculas;
REVOKE SELECT ON SCHEMA::App FROM rol_reportes;
DROP ROLE IF EXISTS rol_reportes;
IF USER_ID('app_ro') IS NOT NULL DROP USER app_ro;
USE master; IF SUSER_ID('app_ro') IS NOT NULL DROP LOGIN app_ro; USE Academia2022;


-- Quitar objetos auxiliares
DROP VIEW IF EXISTS App.vw_ResumenAlumno;
DROP VIEW IF EXISTS App.vw_MatriculasPorCurso;
DROP INDEX IF EXISTS IX_vw_MatriculasPorCurso ON App.vw_MatriculasPorCurso;
DROP INDEX IF EXISTS IX_Matriculas_Curso_Periodo ON Academico.Matriculas;
DROP INDEX IF EXISTS IX_Alumnos_NombreCompleto ON Academico.Alumnos;
DROP SEQUENCE IF EXISTS Academico.SeqCodigoCurso;
--**Por qué:** Permite ejecutar el paquete repetidamente en **ciclos de práctica** sin interferencias.

-------------------------------------------------------------------------------
-- Aca estan los querys del examen funcionando para complementar este archivo.
-------------------------------------------------------------------------------
CREATE TABLE Academico.AlumnosE(
	AlumnoID INT IDENTITY(1,1) CONSTRAINT PK_AlumnosE PRIMARY KEY,
	AlumnoNombre NVARCHAR(60) NOT NULL,
	AlumnoApellido NVARCHAR(60) NOT NULL,
	AlumnoEmail NVARCHAR(120) NULL CONSTRAINT UQ_Alumnos_EmailE UNIQUE,
	AlumnoEdad TINYINT NOT NULL CONSTRAINT CK_Alumno_EdadE CHECK (AlumnoEdad >=16),
	AlumnoActivo BIT NOT NULL CONSTRAINT DF_Alumno_ActivoE DEFAULT (1)
);
GO

--POR QUE?: IDENTITY(1,1) AUTO INCREMENTABLE Y DEBE INICIAR EN 1 Y SUMAR 1
-- PK PRIMARY KEY, UNIQUE EMAIL EVITA DUPLICADOS, CHECK ASEGURA REGLA DE NEGOCIO
-- CON LA EDAD Y DEFAULT DA VALOR SEGURO ESTADO DEL ALUMNO.


--*Enunciado.* Crea Academico.CarrerasE(Nombre UNIQUE)
--y agrega CarreraID como FK *SET NULL* en Alumnos.

CREATE TABLE Academico.CarrerasE(
	CarreraID INT IDENTITY(1,1) CONSTRAINT PK_CarrerasE PRIMARY KEY,
	CarreraNombre NVARCHAR(80) NOT NULL CONSTRAINT UQ_Carreras_NombreE UNIQUE
);
GO

ALTER TABLE Academico.AlumnosE
ADD CarreraID INT NULL CONSTRAINT FK_Alumnos_CarrerasE
FOREIGN KEY (CarreraID) REFERENCES Academico.CarrerasE(CarreraID)
ON DELETE SET NULL ON UPDATE NO ACTION;
GO
--*Por qué:* El catálogo normaliza el dominio; SET NULL 
--evita eliminar accidentalmente alumnos al borrar carreras.

--Insertar una carrera, un alumno asignado a esa carrera; eliminar carrera y demostrar que el alumno queda con CarreraId
INSERT INTO Academico.Carreras (CarreraNombre)
VALUES ('Ingeniería en Sistemas');
GO

SELECT * FROM Academico.Carreras;

DECLARE @CarreraID INT;
SET @CarreraID = SCOPE_IDENTITY();

SELECT a.AlumnoID, a.AlumnoNombre, a.AlumnoApellido, a.AlumnoID, c.CarreraNombre
FROM Academico.Alumnos a
LEFT JOIN Academico.Carreras c ON a.AlumnoID = c.CarreraID;
GO

INSERT INTO Academico.Alumnos 
    (AlumnoNombre, AlumnoApellido, AlumnoEmail, AlumnoEdad, AlumnoActivo) -- Se quita AlumnoID
VALUES 
    ('Bryan', 'Arriaza', 'bryan.arriaza@example.com', 20, 1); -- Se quita el valor 1
GO

select * from Academico.Alumnos;

--Borrar la carrera (esto dejará CarreraID en NULL por ON DELETE SET NULL)
DELETE FROM Academico.Carreras
WHERE CarreraID = @CarreraID;
GO

-- Ver alumnos después del borrado (CarreraID debe ser NULL)
SELECT AlumnoID, AlumnoNombre, AlumnoApellido, CarreraID
FROM Academico.AlumnosE
WHERE AlumnoEmail = 'juan.perez@example.com';
GO

-------------------Ejercicio2
--**Enunciado** Crea Academico.MatriculasE (AlumnoID, CursoID, Periodo CHAR(6))
-- Con PK compuesta y FKs **CASCADE**


CREATE TABLE Academico.Matriculas(
AlumnoID INT NOT NULL,
CursoID INT NOT NULL,
MatriculaPeriodo CHAR(6) NOT NULL CONSTRAINT CK_Matriculas_Periodo 
CHECK (MatriculaPeriodo LIKE '[12][0-9][S][12]'),
CONSTRAINT PK_Matriculas PRIMARY KEY (AlumnoID, CursoID, MatriculaPeriodo), 
CONSTRAINT FK_Matriculas_Alumnos FOREIGN KEY (AlumnoID) 
REFERENCES Academico.Alumnos(AlumnoID) ON DELETE CASCADE,
CONSTRAINT FK_Matriculas_Cursos FOREIGN KEY (CursoID)
REFERENCES Academico.Cursos(CursoID) ON DELETE CASCADE
);
GO

------------------------------
---Ejercicio 3 

INSERT INTO Academico.Alumnos 
    (AlumnoNombre, AlumnoApellido, AlumnoEmail, AlumnoEdad, AlumnoActivo, CarreraID)
VALUES 
    ('Basualdo', 'Davila', 'basualdo.davila@example.com', 25, 1,1);
GO

------------------------------
---Ejercicio 4

CREATE TABLE Academico.Cursos(
CursoID INT IDENTITY(1,1) CONSTRAINT PK_Cursos PRIMARY KEY,
CursoNombre NVARCHAR(100) NOT NULL CONSTRAINT UQ_CursosE_Nombre UNIQUE
);
INSERT INTO Academico.Cursos (CursoNombre, CursoCreditosECTS)
VALUES
    ('Cálculo Avanzado', 6),
    ('Física General', 8),
    ('Programacion', 7);
GO
SELECT * FROM Academico.Cursos;


------Ejercicio5
----------------------

select * from Academia2022.Academico.Cursos;


----------------------------------------------------------

-----EJERCICIO 5 Y 6 
SELECT * FROM Academico.Matriculas;
SELECT * FROM Academico.Alumnos;
SELECT * FROM Academico.Cursos;

INSERT INTO Academia2022.Academico.Matriculas(AlumnoID, CursoID, MatriculaPeriodo)
VALUES (4, 4, '13S2'); 

-- Caso inválido: capturamos error en TRY…CATCH
BEGIN TRY
    INSERT INTO Academico.Matriculas(AlumnoID, CursoID, MatriculaPeriodo)
    VALUES (3, 3, '85S20');   
END TRY
BEGIN CATCH
    PRINT 'Error detectado: ' + ERROR_MESSAGE();
END CATCH;


DELETE FROM Academico.Matriculas 
WHERE AlumnoID = 3 AND CursoID = 3 AND MatriculaPeriodo = '13S2'; 

------------------------------------------------------------------------------
--Aca estan los querys del examen.
------------------------------------------------------------------------------

--Consulta
SELECT NombreCompleto 
FROM Academico.Alumnos 
WHERE AlumnoID=3;

SELECT NombreCompleto 
FROM Academico.Alumnos 
WHERE AlumnoApellido='Arriaza';


-----------------------------------------------------------
--Los atributos de la tabla alumnos
--deberia separar los apellidos
--solucion
--ApellidoPaterno
--ApellidoMaterno


----------------------------------------------------------
--UPPERCASE
--Hace que todo lo ingresado lo muestre en letra mayuscula.
---------------------------------------------------------

--## 13.2 --'SQUENCE' para codigo visible.
--**Enumciado.** Crea 'Academico.Cursos(Codigo  )'

--Solucion
CREATE SQUENCE Academico.SeqCodigoCurso
AS INT START WITH 1000
INCREMENT BY 1;
GO
ALTER TABLE Academico.Cursos
ADD Codigo INT NOT NULL
CONSTRAINT DF_Cursos_Codigo DEFAULT
(NEXT VALUE FOR Academico.SeqCodigoCurso);


--Query que hemos hecho anteriormente en clase.

--**Enunciado.** Crea Academico.SeqCodigoCurso e insertalo como default en columna

CREATE SEQUENCE Academico.SeqCodigoCurso
 AS INT START WITH 1000 
INCREMENT BY 1;
GO
ALTER TABLE Academico.Cursos
ADD CursoCodigo INT NOT NULL
CONSTRAINT DF_Cursos_CursoCodigo DEFAULT 
(NEXT VALUE FOR Academico.SeqCodigoCurso);
GO
--*Por qué:* SEQUENCE es *reutilizable* y configurable (reinicio/salto),
--más flexible que IDENTITY cuando la misma secuencia se usa en varias tablas.

--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------


--** Ejercicio 13.3 — Vista con `SCHEMABINDING` e índice --**
--**Enunciado.** Crear vista  agregada de matrículas por curso y **indexarla**.

--Solucion:Para la vista en entorno SQL Server 2022
--Contexto de SQL: Con las fechas para esta version

  
CREATE VIEW App.vw_MatriculasPorCurso
WITH SCHEMABINDING AS
SELECT
m.CursoID,
COUNT_BIG(*) AS Total
FROM Academico.Matriculas AS m
GROUP BY m.CursoID;
GO
CREATE UNIQUE CLUSTERED INDEX IX_vw_MatriculasPorCurso ON App.vw_MatriculasPorCurso(CursoID);
--*Por qué:* SCHEMABINDING habilita indexación de vistas materiales, 
--acelerando *agregados* frecuentes.

--**
--El error Cannot create index on view... The function 'getdate
--yields nondeterministic results ocurre porque no se puede crear una vista 
--indexada (CREATE UNIQUE CLUSTERED INDEX) si la vista utiliza una función 
--no determinista como GETDATE() en su definición. 
--Una función es no determinista si puede devolver resultados diferentes 
--cada vez que se llama, incluso con los mismos parámetros. GETDATE() 
--siempre devuelve la hora actual, por lo que es un resultado que cambia 
--constantemente. Una vista indexada, para funcionar, debe tener un resultado 
--fijo y predecible. 
--Aquí tienes dos soluciones. La primera es la mejor, y la segunda 
--es una alternativa si no puedes evitar el comportamiento no determinista.


--**

--Solución 1: Retirar la condición de fecha para crear el índice
--La forma más común y eficiente es mover el filtro no determinista 
--(WHERE SUBSTRING(m.MatriculaPeriodo,1,4) = CONVERT(char(4), YEAR(GETDATE())))
--a la consulta que use la vista. El índice se crea en la vista sin el filtro,
--lo que acelera todas las consultas que accedan a ella, y luego aplicas el filtro 
--de año actual al consultar la vista.


SELECT
    v.CursoID,
    v.Total
FROM
    App.vw_MatriculasPorCurso AS v
--AQUI REALIZO LA CONDICION PARA LA FECHA 
WHERE
    SUBSTRING(v.MatriculaPeriodo, 1, 4) = CONVERT(CHAR(4), YEAR(GETDATE()));




--Solucion #2


-------------------------------------------------------------------------------------------------------------
--Clase fecha: 05/10/2025
-------------------------------------------------------------------------------------------------------------



-------------------------------------------------------------------------------------------------------------
--Clase fecha: 12/10/2025
-------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------
--Clase fecha: 19/10/2025
-------------------------------------------------------------------------------------------------------------


/*
================================================================================
 ENTREGABLE EQUIPO C: SQL DE REPORTES Y PERFORMANCE
 Basado en el proyecto de Academia2022.
================================================================================
*/
USE Academia2022;
GO

--------------------------------------------------------------------------------
-- Hito 3: Vistas Indexadas para KPIs (Top cursos, Carga por alumno, Ocupación por periodo)
-- 
--------------------------------------------------------------------------------

-- NOTA: La vista App.vw_MatriculasPorCurso (KPI "Top Cursos")
-- ya está creada en el script 'Query_BryanArriaza_CORRECCION.sql' (línea 377).
-- Solo la usaremos.

-- KPI 2: VISTA INDEXADA "CARGA POR ALUMNO"
-- Propósito: Materializa el conteo de cursos por alumno y periodo.
PRINT 'Creando App.vw_CargaPorAlumno...';
GO
IF OBJECT_ID('App.vw_CargaPorAlumno', 'V') IS NOT NULL
    DROP VIEW App.vw_CargaPorAlumno;
GO

CREATE VIEW App.vw_CargaPorAlumno
WITH SCHEMABINDING -- Requerido para indexar
AS
SELECT
    m.AlumnoID,
    m.MatriculaPeriodo,
    COUNT_BIG(*) AS TotalCursos -- Requerido para indexar
FROM
    Academico.Matriculas AS m
GROUP BY
    m.AlumnoID, m.MatriculaPeriodo;
GO

-- Creación del índice que materializa la vista
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'UCI_vw_CargaPorAlumno')
    CREATE UNIQUE CLUSTERED INDEX UCI_vw_CargaPorAlumno
    ON App.vw_CargaPorAlumno(AlumnoID, MatriculaPeriodo);
GO

-- KPI 3: VISTA INDEXADA "OCUPACIÓN POR PERIODO"
-- Propósito: Materializa el total de matrículas (ocupación) por periodo.
PRINT 'Creando App.vw_OcupacionPorPeriodo...';
GO
IF OBJECT_ID('App.vw_OcupacionPorPeriodo', 'V') IS NOT NULL
    DROP VIEW App.vw_OcupacionPorPeriodo;
GO

CREATE VIEW App.vw_OcupacionPorPeriodo
WITH SCHEMABINDING
AS
SELECT
    m.MatriculaPeriodo,
    COUNT_BIG(*) AS TotalMatriculas
FROM
    Academico.Matriculas AS m
GROUP BY
    m.MatriculaPeriodo;
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'UCI_vw_OcupacionPorPeriodo')
    CREATE UNIQUE CLUSTERED INDEX UCI_vw_OcupacionPorPeriodo
    ON App.vw_OcupacionPorPeriodo(MatriculaPeriodo);
GO

PRINT '--- Vistas Indexadas de KPIs creadas con éxito. ---';
GO


--------------------------------------------------------------------------------
-- Alcance: Consultas analíticas (Ventanas, PIVOT, Subconsultas)
-- 
-- Estas consultas son las que USAREMOS para el análisis de performance.
--------------------------------------------------------------------------------

PRINT '--- EJECUTANDO CONSULTAS ANALÍTICAS ---';

--
-- CONSULTA 1: FUNCIONES DE VENTANA (Window Functions)
-- Objetivo: Ranking de alumnos por carga académica en cada periodo,
-- y comparar la carga con el periodo anterior (LAG).
--
PRINT 'Consulta 1: Funciones de Ventana (Ranking y LAG)';
GO
WITH CargaPorPeriodo AS (
    -- 1. Agregamos la carga base
    SELECT
        AlumnoID,
        MatriculaPeriodo,
        COUNT(*) AS CursosInscritos
    FROM Academico.Matriculas
    GROUP BY AlumnoID, MatriculaPeriodo
)
-- 2. Aplicamos ventanas y unimos con Alumnos
SELECT
    a.NombreCompleto,
    c.MatriculaPeriodo,
    c.CursosInscritos,
    
    -- KPI: Ranking de alumnos por periodo (más inscritos primero)
    DENSE_RANK() OVER(PARTITION BY c.MatriculaPeriodo 
                      ORDER BY c.CursosInscritos DESC) AS RankingCarga,
    
    -- KPI: Comparativa de carga vs periodo anterior
    LAG(c.CursosInscritos, 1, 0) OVER(PARTITION BY c.AlumnoID 
                                     ORDER BY c.MatriculaPeriodo) AS CargaPeriodoAnterior
FROM CargaPorPeriodo c
JOIN Academico.Alumnos a ON c.AlumnoID = a.AlumnoID -- Join costoso
ORDER BY
    c.MatriculaPeriodo, RankingCarga;
GO


--
-- CONSULTA 2: PIVOT
-- Objetivo: Mostrar la cantidad de alumnos por curso, pivotando
-- los periodos como columnas (Reporte tipo Excel).
--
PRINT 'Consulta 2: PIVOT (Matrículas por Curso/Periodo)';
GO
-- Definimos los periodos que queremos como columnas
DECLARE @ColumnasPivot NVARCHAR(MAX) = N'[24S1], [24S2], [25S1]'; 
-- (Se podrían hacer dinámicas, pero para el reporte se definen estáticas)

-- 1. Obtenemos la base de matriculas por curso y periodo
WITH BasePivot AS (
    SELECT CursoID, MatriculaPeriodo, COUNT(*) AS TotalAlumnos
    FROM Academico.Matriculas
    GROUP BY CursoID, MatriculaPeriodo
)
-- 2. Aplicamos PIVOT
SELECT
    c.CursoNombre,
    ISNULL(p.[24S1], 0) AS [Periodo 24S1],
    ISNULL(p.[24S2], 0) AS [Periodo 24S2],
    ISNULL(p.[25S1], 0) AS [Periodo 25S1]
FROM (
    SELECT CursoID, MatriculaPeriodo, TotalAlumnos FROM BasePivot
) AS FuenteDatos
PIVOT (
    SUM(TotalAlumnos) -- Función de Agregado
    FOR MatriculaPeriodo IN ([24S1], [24S2], [25S1]) -- Columnas a crear
) AS p
JOIN Academico.Cursos c ON p.CursoID = c.CursoID -- Join para nombre
ORDER BY
    c.CursoNombre;
GO

--
-- CONSULTA 3: SUBCONSULTA CORRELACIONADA
-- Objetivo: Obtener la matrícula más reciente (último periodo) de cada alumno.
--
PRINT 'Consulta 3: Subconsulta Correlacionada (Última Matrícula)';
GO
SELECT
    a.NombreCompleto,
    c.CursoNombre,
    m.MatriculaPeriodo
FROM
    Academico.Matriculas m
JOIN
    Academico.Alumnos a ON m.AlumnoID = a.AlumnoID
JOIN
    Academico.Cursos c ON m.CursoID = c.CursoID
WHERE
    m.MatriculaPeriodo = (
        -- Subconsulta Correlacionada:
        -- Por cada fila 'm', esta subconsulta se re-ejecuta
        -- para encontrar el periodo máximo SOLO para ese alumno.
        SELECT MAX(m2.MatriculaPeriodo)
        FROM Academico.Matriculas m2
        WHERE m2.AlumnoID = m.AlumnoID
    );
GO

PRINT '--- Fin del script de reportes. ---';