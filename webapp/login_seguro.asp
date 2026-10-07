<%
Dim conn, cmd, rs, usuario, clave

usuario = Request.Form("User")
clave   = Request.Form("password")

Set conn = Server.CreateObject("ADODB.Connection")
conn.Open "Provider=MSOLEDBSQL19;Server=localhost;Database=LabSQLi;" & _
          "UID=webuser;PWD=WebPass123!;Use Encryption for Data=True;Trust Server Certificate=True;"

Set cmd = Server.CreateObject("ADODB.Command")
cmd.ActiveConnection = conn
cmd.CommandText = "SELECT * FROM Usuarios WHERE usuario = ? AND clave = ?"
cmd.CommandType = 1 ' adCmdText

cmd.Parameters.Append cmd.CreateParameter("p_usuario", 200, 1, 50, usuario) ' adVarChar, adParamInput
cmd.Parameters.Append cmd.CreateParameter("p_clave",   200, 1, 50, clave)

Set rs = cmd.Execute()

If Not rs.EOF Then
    Response.Write "Acceso concedido. Bienvenido " & rs("usuario")
Else
    Response.Write "Usuario o clave incorrectos."
End If

rs.Close
conn.Close
%>
