<%
Dim conn, rs, sql, usuarioInput, clave

Response.Write "version nueva"

usuarioInput = Request.Form("User")
clave = Request.Form("password")

Set conn = Server.CreateObject("ADODB.Connection")
conn.Open "Provider=MSOLEDBSQL19;Server=localhost;Database=LabSQLi;UID=webuser;PWD=WebPass123!;Use Encryption for Data=True;Trust Server Certificate=True;"

sql = "SELECT * FROM Usuarios WHERE usuario='" & usuarioInput & _
  "' AND clave='" & clave & "'"

Set rs = conn.Execute(sql)

If Not rs.EOF Then
  Response.Write "Acceso concedido. Bienvenido " & rs("usuario")
Else
  Response.Write "Usuario o clave incorrectos."
End If

rs.Close
conn.Close
%>
