// Captures d'écran périodiques DE LA VM de test pendant une tâche (facultatif).
//
// Ce source est copié avec chaque tâche puis compilé DANS LA VM par le
// compilateur C# livré avec Windows (.NET Framework 4, csc.exe), vers
// %LOCALAPPDATA%\AutomotiveWorldTests\bin\aw-capture.exe. Aucun binaire n'est
// téléchargé ni transporté : seul ce fichier texte, lisible, voyage.
// Il remplace l'ancien script PowerShell de capture, que l'antivirus de la VM
// (AMSI) bloquait et qui exigeait une exclusion Microsoft Defender.
//
// Usage : aw-capture.exe <dossier de sortie> <fichier d'arrêt> <intervalle s> <nombre max>
// S'arrête quand le fichier d'arrêt apparaît. Ne jamais l'exécuter sur un poste
// de travail : il capture l'écran entier.

using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Threading;
using System.Windows.Forms;

internal static class AwCapture
{
    private static int Main(string[] args)
    {
        if (args.Length < 4)
        {
            return 2;
        }
        string outDir = args[0];
        string stopFile = args[1];
        double intervalSec = double.Parse(args[2], CultureInfo.InvariantCulture);
        int maxShots = int.Parse(args[3], CultureInfo.InvariantCulture);
        Directory.CreateDirectory(outDir);

        ImageCodecInfo jpeg = null;
        foreach (ImageCodecInfo codec in ImageCodecInfo.GetImageEncoders())
        {
            if (codec.MimeType == "image/jpeg")
            {
                jpeg = codec;
            }
        }
        if (jpeg == null)
        {
            return 3;
        }
        EncoderParameters quality = new EncoderParameters(1);
        quality.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, 70L);

        int count = 0;
        while (!File.Exists(stopFile) && count < maxShots)
        {
            try
            {
                Rectangle bounds = SystemInformation.VirtualScreen;
                using (Bitmap full = new Bitmap(bounds.Width, bounds.Height))
                using (Graphics graphics = Graphics.FromImage(full))
                {
                    graphics.CopyFromScreen(bounds.Left, bounds.Top, 0, 0, full.Size);
                    // Image réduite de moitié (taille des rapports).
                    using (Bitmap small = new Bitmap(bounds.Width / 2, bounds.Height / 2))
                    using (Graphics smallGraphics = Graphics.FromImage(small))
                    {
                        smallGraphics.DrawImage(full, 0, 0, small.Width, small.Height);
                        count++;
                        small.Save(Path.Combine(outDir, count.ToString("D4") + ".jpg"), jpeg, quality);
                    }
                }
            }
            catch (Exception)
            {
                // Écran verrouillé ou indisponible : nouvel essai au tour suivant.
            }
            Thread.Sleep((int)(intervalSec * 1000));
        }
        return 0;
    }
}
