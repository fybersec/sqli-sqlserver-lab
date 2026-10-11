USE LabsSQLI;
CREATE TABLE Usuarios (
id INT PRIMARY KEY IDENTITY,
usuario VARCHAR(50),
clave VARCHAR(50),
rol VARCHAR(20)
);

INSERT INTO Usuarios (usuario,clave,rol) VALUES
('admin','Admin1234!','administrador'),
('jperez','Clave456!','usuario');