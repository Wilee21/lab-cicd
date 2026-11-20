# Acceso a los secretos del laboratorio en el Administrador de credenciales de Windows.
# Windows los cifra con DPAPI: solo la misma cuenta de Windows, en este equipo, puede leerlos.
# Cada secreto se guarda como credencial genérica "LabCICD/<NOMBRE>". Este archivo se incluye con:
#   . (Join-Path $PSScriptRoot 'Secretos.ps1')

# Secretos que usa el entorno de Jenkins (ver README, "Secretos").
$LabSecretos = @('JENKINS_ADMIN_PASSWORD', 'JENKINS_LECTOR_PASSWORD', 'DOCKERHUB_TOKEN')

if (-not ('LabCredenciales' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

public static class LabCredenciales {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CREDENTIAL {
        public int Flags;
        public int Type;
        public string TargetName;
        public string Comment;
        public long LastWritten;
        public int CredentialBlobSize;
        public IntPtr CredentialBlob;
        public int Persist;
        public int AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    private const int TipoGenerico = 1;        // CRED_TYPE_GENERIC
    private const int PersistirEnEquipo = 2;   // CRED_PERSIST_LOCAL_MACHINE

    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredRead(string target, int type, int flags, out IntPtr credential);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredWrite(ref CREDENTIAL credential, int flags);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredDelete(string target, int type, int flags);
    [DllImport("advapi32.dll")]
    private static extern void CredFree(IntPtr buffer);

    public static string Leer(string target) {
        IntPtr puntero;
        if (!CredRead(target, TipoGenerico, 0, out puntero)) return null;
        try {
            CREDENTIAL c = (CREDENTIAL)Marshal.PtrToStructure(puntero, typeof(CREDENTIAL));
            if (c.CredentialBlobSize == 0) return "";
            return Marshal.PtrToStringUni(c.CredentialBlob, c.CredentialBlobSize / 2);
        } finally {
            CredFree(puntero);
        }
    }

    public static void Guardar(string target, string usuario, string valor) {
        byte[] bytes = Encoding.Unicode.GetBytes(valor);
        CREDENTIAL c = new CREDENTIAL();
        c.Type = TipoGenerico;
        c.TargetName = target;
        c.UserName = usuario;
        c.Persist = PersistirEnEquipo;
        c.CredentialBlobSize = bytes.Length;
        c.CredentialBlob = Marshal.AllocHGlobal(bytes.Length);
        try {
            Marshal.Copy(bytes, 0, c.CredentialBlob, bytes.Length);
            if (!CredWrite(ref c, 0)) throw new Win32Exception(Marshal.GetLastWin32Error());
        } finally {
            Marshal.FreeHGlobal(c.CredentialBlob);
        }
    }

    public static bool Borrar(string target) {
        return CredDelete(target, TipoGenerico, 0);
    }
}
'@
}

function Leer-Secreto([string]$Nombre) { [LabCredenciales]::Leer("LabCICD/$Nombre") }
function Guardar-Secreto([string]$Nombre, [string]$Valor) { [LabCredenciales]::Guardar("LabCICD/$Nombre", $Nombre, $Valor) }
function Borrar-Secreto([string]$Nombre) { [void][LabCredenciales]::Borrar("LabCICD/$Nombre") }
