// Captures d'écran périodiques DE LA VM de test pendant une tâche (facultatif),
// et, au lot 0.9.1, pont d'ENTRÉES RÉELLES (souris, clavier) facultatif.
//
// Ce source est copié avec chaque tâche puis compilé DANS LA VM par le
// compilateur C# livré avec Windows (.NET Framework 4, csc.exe), vers
// %LOCALAPPDATA%\AutomotiveWorldTests\bin\aw-capture.exe. Aucun binaire n'est
// téléchargé ni transporté : seul ce fichier texte, lisible, voyage.
// Il remplace l'ancien script PowerShell de capture, que l'antivirus de la VM
// (AMSI) bloquait et qui exigeait une exclusion Microsoft Defender.
//
// Usage : aw-capture.exe <dossier de sortie> <fichier d'arrêt> <intervalle s> <nombre max>
//                        [<dossier des journaux Roblox> <dossier du pont d'entrées>]
// S'arrête quand le fichier d'arrêt apparaît. Ne jamais l'exécuter sur un poste
// de travail : il capture l'écran entier et, avec les deux derniers arguments,
// produit de vraies entrées souris et clavier dans la session Windows où il tourne.
//
// Pont d'entrées (lot 0.9.1) — pourquoi : tester les interfaces du jeu par de vrais
// clics et de vraies touches, et non en appelant leurs fonctions. Le client de test
// imprime des commandes « @@AWIN@@ <n> <op> <arguments> » ; Studio les écrit dans son
// journal (%LOCALAPPDATA%\Roblox\logs), que ce programme lit au fil de l'eau. Il les
// exécute par SendInput (API Windows), comme une souris et un clavier physiques :
//   calib n ax ay bx by vw vh
//                        repère deux carrés magenta (255, 0, 255) affichés par le test ;
//                        (ax, ay) = coin haut-gauche du premier, (bx, by) = coin
//                        bas-droit du second, (vw, vh) = taille de la vue, en pixels de
//                        la vue du jeu. Donne la correspondance vue → écran (décalage et
//                        échelle). Les carrés sont posés À L'INTÉRIEUR de la vue : les
//                        coins sont couverts par la barre de Roblox et le filigrane Windows.
//   click n x y          clic gauche au point (x, y) de la vue du jeu.
//   move n x y           déplace seulement le pointeur.
//   key n vk ms          appui sur une touche (code virtuel), maintenue ms millisecondes.
//   down n vk / up n vk  maintien / relâchement d'une touche (conduite au clavier).
//   skey n sc ms / sdown n sc / sup n sc
//                        mêmes actions par code de balayage (position physique de la
//                        touche, clavier américain) : indépendant de la disposition
//                        (AZERTY de la VM) ; le client choisit le mode que le jeu reçoit.
//   type n hex           saisie de texte (UTF-8 en hexadécimal), caractère par caractère.
//   wheel n x y crans    molette (positif : vers le haut).
//   shot n nom           capture nommée de la vue du jeu (pleine résolution).
// Garde-fous : aucune action avant l'étalonnage ; pointeur limité au rectangle de la
// vue du jeu (jamais la barre d'outils de Studio, donc jamais « Arrêter ») ; touches
// limitées à une liste (lettres, chiffres, espace, entrée, échap, retour, tabulation,
// flèches, barre oblique inverse, Maj ; mêmes touches en codes de balayage) : ni
// touches de fonction, ni Ctrl ni Alt, donc aucun raccourci de Studio. Chaque commande est consignée dans input-log.txt.

using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;

internal static class AwCapture
{
    private static ImageCodecInfo jpeg;

    [DllImport("user32.dll")]
    private static extern bool SetProcessDPIAware();

    private static int Main(string[] args)
    {
        if (args.Length < 4)
        {
            return 2;
        }
        // Coordonnées physiques : captures et entrées dans le même repère, quelle que
        // soit la mise à l'échelle de l'affichage de la VM.
        SetProcessDPIAware();
        string outDir = args[0];
        string stopFile = args[1];
        double intervalSec = double.Parse(args[2], CultureInfo.InvariantCulture);
        int maxShots = int.Parse(args[3], CultureInfo.InvariantCulture);
        Directory.CreateDirectory(outDir);

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

        if (args.Length >= 6)
        {
            InputBridge bridge = new InputBridge(args[4], args[5], stopFile);
            Thread thread = new Thread(bridge.Run);
            thread.IsBackground = true;
            thread.Start();
        }

        int count = 0;
        while (!File.Exists(stopFile) && count < maxShots)
        {
            try
            {
                using (Bitmap full = CaptureScreen())
                // Image réduite de moitié (taille des rapports).
                using (Bitmap small = new Bitmap(full.Width / 2, full.Height / 2))
                using (Graphics smallGraphics = Graphics.FromImage(small))
                {
                    smallGraphics.DrawImage(full, 0, 0, small.Width, small.Height);
                    count++;
                    SaveJpeg(small, Path.Combine(outDir, count.ToString("D4") + ".jpg"), 70L);
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

    internal static Bitmap CaptureScreen()
    {
        Rectangle bounds = SystemInformation.VirtualScreen;
        Bitmap full = new Bitmap(bounds.Width, bounds.Height, PixelFormat.Format32bppArgb);
        using (Graphics graphics = Graphics.FromImage(full))
        {
            graphics.CopyFromScreen(bounds.Left, bounds.Top, 0, 0, full.Size);
        }
        return full;
    }

    internal static void SaveJpeg(Bitmap image, string path, long quality)
    {
        EncoderParameters parameters = new EncoderParameters(1);
        parameters.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, quality);
        image.Save(path, jpeg, parameters);
    }
}

// Lecture des commandes dans les journaux Studio et exécution par SendInput.
internal sealed class InputBridge
{
    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct INPUTUNION
    {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public uint type;
        public INPUTUNION u;
    }

    private const uint INPUT_MOUSE = 0;
    private const uint INPUT_KEYBOARD = 1;
    private const uint MOUSEEVENTF_MOVE = 0x0001;
    private const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    private const uint MOUSEEVENTF_LEFTUP = 0x0004;
    private const uint MOUSEEVENTF_WHEEL = 0x0800;
    private const uint MOUSEEVENTF_ABSOLUTE = 0x8000;
    private const uint MOUSEEVENTF_VIRTUALDESK = 0x4000;
    private const uint KEYEVENTF_EXTENDEDKEY = 0x0001;
    private const uint KEYEVENTF_KEYUP = 0x0002;
    private const uint KEYEVENTF_UNICODE = 0x0004;
    private const uint KEYEVENTF_SCANCODE = 0x0008;

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint count, INPUT[] inputs, int size);

    [DllImport("user32.dll")]
    private static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    private static extern uint MapVirtualKey(uint code, uint mapType);

    private static readonly Regex CommandPattern = new Regex(@"@@AWIN@@ (\d+) ([a-z]+)((?: [^ \r\n]+)*)");

    private readonly string logsDir;
    private readonly string bridgeDir;
    private readonly string stopFile;
    private readonly Dictionary<string, long> positions = new Dictionary<string, long>();
    private readonly HashSet<string> done = new HashSet<string>();
    private readonly HashSet<int> held = new HashSet<int>();
    private StreamWriter log;
    private bool calibrated;
    private double originX, originY, scaleX = 1, scaleY = 1;
    private double viewWidth, viewHeight;
    private int namedShots;

    public InputBridge(string logsDir, string bridgeDir, string stopFile)
    {
        this.logsDir = logsDir;
        this.bridgeDir = bridgeDir;
        this.stopFile = stopFile;
    }

    public void Run()
    {
        Directory.CreateDirectory(bridgeDir);
        Directory.CreateDirectory(Path.Combine(bridgeDir, "named"));
        log = new StreamWriter(Path.Combine(bridgeDir, "input-log.txt"), true, new UTF8Encoding(false));
        log.AutoFlush = true;
        Note("pont démarré, journaux lus dans " + logsDir);
        // Les journaux déjà présents (anciennes sessions) sont lus à partir de leur fin.
        foreach (string file in SafeFiles())
        {
            positions[file] = new FileInfo(file).Length;
        }
        while (!File.Exists(stopFile))
        {
            try
            {
                foreach (string file in SafeFiles())
                {
                    ReadNew(file);
                }
            }
            catch (Exception error)
            {
                Note("erreur de lecture : " + error.Message);
            }
            Thread.Sleep(60);
        }
        // Touches encore enfoncées à l'arrêt : relâchées (négatif = code de balayage).
        foreach (int code in new List<int>(held))
        {
            if (code < 0)
            {
                Scan(-code, true);
            }
            else
            {
                Key(code, true);
            }
        }
        Note("pont arrêté");
    }

    private IEnumerable<string> SafeFiles()
    {
        if (!Directory.Exists(logsDir))
        {
            return new string[0];
        }
        return Directory.GetFiles(logsDir, "*.log");
    }

    private void ReadNew(string file)
    {
        long start;
        if (!positions.TryGetValue(file, out start))
        {
            start = 0;
        }
        using (FileStream stream = new FileStream(file, FileMode.Open, FileAccess.Read,
            FileShare.ReadWrite | FileShare.Delete))
        {
            if (stream.Length <= start)
            {
                positions[file] = Math.Min(start, stream.Length);
                return;
            }
            stream.Seek(start, SeekOrigin.Begin);
            byte[] buffer = new byte[stream.Length - start];
            int read = stream.Read(buffer, 0, buffer.Length);
            // Seules les lignes complètes sont traitées ; la fin partielle sera relue.
            int lastNewline = Array.LastIndexOf(buffer, (byte)'\n', read - 1);
            if (lastNewline < 0)
            {
                return;
            }
            positions[file] = start + lastNewline + 1;
            string text = Encoding.UTF8.GetString(buffer, 0, lastNewline + 1);
            foreach (Match match in CommandPattern.Matches(text))
            {
                string key = Path.GetFileName(file) + "#" + match.Groups[1].Value;
                if (done.Add(key))
                {
                    string[] parts = match.Groups[3].Value.Trim().Split(new[] { ' ' },
                        StringSplitOptions.RemoveEmptyEntries);
                    Execute(match.Groups[1].Value, match.Groups[2].Value, parts);
                }
            }
        }
    }

    private void Note(string text)
    {
        log.WriteLine(DateTime.UtcNow.ToString("o") + " " + text);
    }

    private static double Num(string[] parts, int index)
    {
        return double.Parse(parts[index], CultureInfo.InvariantCulture);
    }

    private void Execute(string id, string op, string[] parts)
    {
        try
        {
            if (op == "calib")
            {
                Calibrate(id, Num(parts, 0), Num(parts, 1), Num(parts, 2), Num(parts, 3),
                    parts.Length >= 6 ? Num(parts, 4) : Num(parts, 2) + Num(parts, 0),
                    parts.Length >= 6 ? Num(parts, 5) : Num(parts, 3) + Num(parts, 1));
                return;
            }
            if (op == "shot")
            {
                Shot(id, parts.Length > 0 ? parts[0] : "sans_nom");
                return;
            }
            if (!calibrated)
            {
                Note(id + " " + op + " refusé : pas d'étalonnage");
                return;
            }
            switch (op)
            {
                case "click":
                    Point point;
                    if (ToScreen(Num(parts, 0), Num(parts, 1), out point))
                    {
                        MoveTo(point);
                        Thread.Sleep(90);
                        Mouse(MOUSEEVENTF_LEFTDOWN, 0);
                        Thread.Sleep(70);
                        Mouse(MOUSEEVENTF_LEFTUP, 0);
                        Note(id + " clic vue (" + parts[0] + ", " + parts[1] + ") écran (" + point.X + ", " + point.Y + ")");
                    }
                    else
                    {
                        Note(id + " clic refusé : hors de la vue du jeu (" + parts[0] + ", " + parts[1] + ")");
                    }
                    break;
                case "move":
                    Point target;
                    if (ToScreen(Num(parts, 0), Num(parts, 1), out target))
                    {
                        MoveTo(target);
                        Note(id + " pointeur écran (" + target.X + ", " + target.Y + ")");
                    }
                    break;
                case "wheel":
                    Point wheelAt;
                    if (ToScreen(Num(parts, 0), Num(parts, 1), out wheelAt))
                    {
                        MoveTo(wheelAt);
                        Thread.Sleep(60);
                        Mouse(MOUSEEVENTF_WHEEL, (int)Num(parts, 2) * 120);
                        Note(id + " molette " + parts[2]);
                    }
                    break;
                case "key":
                    int vk = (int)Num(parts, 0);
                    int holdMs = parts.Length > 1 ? (int)Num(parts, 1) : 60;
                    if (Allowed(vk))
                    {
                        Key(vk, false);
                        Thread.Sleep(Math.Max(20, Math.Min(holdMs, 10000)));
                        Key(vk, true);
                        Note(id + " touche " + vk + " (" + holdMs + " ms)");
                    }
                    else
                    {
                        Note(id + " touche " + vk + " refusée (hors liste)");
                    }
                    break;
                case "down":
                case "up":
                    int code = (int)Num(parts, 0);
                    if (Allowed(code))
                    {
                        Key(code, op == "up");
                        if (op == "down")
                        {
                            held.Add(code);
                        }
                        else
                        {
                            held.Remove(code);
                        }
                        Note(id + " touche " + code + (op == "down" ? " enfoncée" : " relâchée"));
                    }
                    else
                    {
                        Note(id + " touche " + code + " refusée (hors liste)");
                    }
                    break;
                case "skey":
                case "sdown":
                case "sup":
                    int sc = (int)Num(parts, 0);
                    if (!AllowedScan(sc))
                    {
                        Note(id + " code de balayage " + sc + " refusé (hors liste)");
                        break;
                    }
                    if (op == "skey")
                    {
                        int scanHold = parts.Length > 1 ? (int)Num(parts, 1) : 60;
                        Scan(sc, false);
                        Thread.Sleep(Math.Max(20, Math.Min(scanHold, 10000)));
                        Scan(sc, true);
                        Note(id + " balayage " + sc + " (" + scanHold + " ms)");
                    }
                    else
                    {
                        Scan(sc, op == "sup");
                        if (op == "sdown")
                        {
                            held.Add(-sc);
                        }
                        else
                        {
                            held.Remove(-sc);
                        }
                        Note(id + " balayage " + sc + (op == "sdown" ? " enfoncé" : " relâché"));
                    }
                    break;
                case "type":
                    string text = Encoding.UTF8.GetString(FromHex(parts.Length > 0 ? parts[0] : ""));
                    foreach (char c in text)
                    {
                        Unicode(c, false);
                        Unicode(c, true);
                        Thread.Sleep(25);
                    }
                    Note(id + " saisie de " + text.Length + " caractère(s)");
                    break;
                default:
                    Note(id + " commande inconnue : " + op);
                    break;
            }
        }
        catch (Exception error)
        {
            Note(id + " " + op + " erreur : " + error.Message);
        }
    }

    // Lettres, chiffres, espace, entrée, échap, retour, tabulation, flèches, « \ », Maj.
    private static bool Allowed(int vk)
    {
        if (vk >= 0x41 && vk <= 0x5A)
        {
            return true;
        }
        if (vk >= 0x30 && vk <= 0x39)
        {
            return true;
        }
        if (vk >= 0x25 && vk <= 0x28)
        {
            return true;
        }
        return vk == 0x20 || vk == 0x0D || vk == 0x1B || vk == 0x08 || vk == 0x09 || vk == 0xDC || vk == 0xE2
            || vk == 0x10 || vk == 0xA0;
    }

    // Mêmes touches en codes de balayage (disposition américaine) ; flèches étendues.
    private static bool AllowedScan(int sc)
    {
        if (sc >= 0x01 && sc <= 0x0B)
        {
            return true;
        }
        if (sc >= 0x10 && sc <= 0x19)
        {
            return true;
        }
        if (sc >= 0x1E && sc <= 0x26)
        {
            return true;
        }
        if (sc >= 0x2A && sc <= 0x32)
        {
            return true;
        }
        return sc == 0x0E || sc == 0x0F || sc == 0x1C || sc == 0x39 || sc == 0x48 || sc == 0x4B || sc == 0x4D
            || sc == 0x50;
    }

    private void Calibrate(string id, double ax, double ay, double bx, double by, double vw, double vh)
    {
        using (Bitmap screen = AwCapture.CaptureScreen())
        {
            Rectangle area = new Rectangle(0, 0, screen.Width, screen.Height);
            BitmapData data = screen.LockBits(area, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            int stride = data.Stride;
            byte[] pixels = new byte[stride * screen.Height];
            Marshal.Copy(data.Scan0, pixels, 0, pixels.Length);
            screen.UnlockBits(data);
            int minX = int.MaxValue, minY = int.MaxValue, maxX = -1, maxY = -1, found = 0;
            for (int y = 0; y < screen.Height; y++)
            {
                int row = y * stride;
                for (int x = 0; x < screen.Width; x++)
                {
                    int i = row + x * 4;
                    // Ordre BGRA : magenta pur, tolérance faible (interface non retouchée).
                    if (pixels[i + 2] >= 235 && pixels[i + 1] <= 25 && pixels[i] >= 235)
                    {
                        found++;
                        if (x < minX) minX = x;
                        if (y < minY) minY = y;
                        if (x > maxX) maxX = x;
                        if (y > maxY) maxY = y;
                    }
                }
            }
            if (found < 200 || bx <= ax || by <= ay)
            {
                calibrated = false;
                Note(id + " étalonnage impossible : " + found + " pixel(s) magenta");
                return;
            }
            scaleX = (maxX + 1 - minX) / (bx - ax);
            scaleY = (maxY + 1 - minY) / (by - ay);
            originX = minX - ax * scaleX;
            originY = minY - ay * scaleY;
            viewWidth = vw;
            viewHeight = vh;
            calibrated = true;
            Note(string.Format(CultureInfo.InvariantCulture,
                "{0} étalonnage : {1} pixels, écran ({2}, {3})–({4}, {5}), échelle {6:F3} × {7:F3}, origine ({8:F1}, {9:F1})",
                id, found, minX, minY, maxX, maxY, scaleX, scaleY, originX, originY));
        }
    }

    private bool ToScreen(double x, double y, out Point point)
    {
        point = new Point((int)Math.Round(originX + x * scaleX), (int)Math.Round(originY + y * scaleY));
        return x >= 0 && y >= 0 && x <= viewWidth && y <= viewHeight;
    }

    private void Shot(string id, string name)
    {
        if (namedShots >= 300)
        {
            Note(id + " capture « " + name + " » refusée : 300 captures nommées atteintes");
            return;
        }
        string safe = Regex.Replace(name, "[^A-Za-z0-9_.-]", "_");
        using (Bitmap screen = AwCapture.CaptureScreen())
        {
            Rectangle crop = new Rectangle(0, 0, screen.Width, screen.Height);
            if (calibrated)
            {
                crop = Rectangle.Intersect(crop, new Rectangle((int)originX, (int)originY,
                    (int)(viewWidth * scaleX), (int)(viewHeight * scaleY)));
            }
            using (Bitmap view = screen.Clone(crop, screen.PixelFormat))
            {
                namedShots++;
                string file = namedShots.ToString("D3") + "_" + safe + ".jpg";
                AwCapture.SaveJpeg(view, Path.Combine(bridgeDir, "named", file), 85L);
                Note(id + " capture " + file + " (" + crop.Width + " × " + crop.Height + ")");
            }
        }
    }

    private static byte[] FromHex(string hex)
    {
        byte[] bytes = new byte[hex.Length / 2];
        for (int i = 0; i < bytes.Length; i++)
        {
            bytes[i] = byte.Parse(hex.Substring(i * 2, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        }
        return bytes;
    }

    private static void MoveTo(Point point)
    {
        SetCursorPos(point.X, point.Y);
        // Mouvement absolu en plus : certaines applications ne suivent que les entrées.
        Rectangle desk = SystemInformation.VirtualScreen;
        INPUT[] inputs = new INPUT[1];
        inputs[0].type = INPUT_MOUSE;
        inputs[0].u.mi.dx = (int)((point.X - desk.Left) * 65535.0 / Math.Max(1, desk.Width - 1));
        inputs[0].u.mi.dy = (int)((point.Y - desk.Top) * 65535.0 / Math.Max(1, desk.Height - 1));
        inputs[0].u.mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK;
        SendInput(1, inputs, Marshal.SizeOf(typeof(INPUT)));
    }

    private static void Mouse(uint flags, int data)
    {
        INPUT[] inputs = new INPUT[1];
        inputs[0].type = INPUT_MOUSE;
        inputs[0].u.mi.dwFlags = flags;
        inputs[0].u.mi.mouseData = unchecked((uint)data);
        SendInput(1, inputs, Marshal.SizeOf(typeof(INPUT)));
    }

    private static void Key(int vk, bool up)
    {
        INPUT[] inputs = new INPUT[1];
        inputs[0].type = INPUT_KEYBOARD;
        inputs[0].u.ki.wVk = (ushort)vk;
        inputs[0].u.ki.wScan = (ushort)MapVirtualKey((uint)vk, 0);
        uint flags = up ? KEYEVENTF_KEYUP : 0;
        if (vk >= 0x25 && vk <= 0x28)
        {
            flags |= KEYEVENTF_EXTENDEDKEY;
        }
        inputs[0].u.ki.dwFlags = flags;
        SendInput(1, inputs, Marshal.SizeOf(typeof(INPUT)));
    }

    private static void Scan(int sc, bool up)
    {
        INPUT[] inputs = new INPUT[1];
        inputs[0].type = INPUT_KEYBOARD;
        inputs[0].u.ki.wScan = (ushort)sc;
        uint flags = KEYEVENTF_SCANCODE | (up ? KEYEVENTF_KEYUP : 0);
        if (sc == 0x48 || sc == 0x4B || sc == 0x4D || sc == 0x50)
        {
            flags |= KEYEVENTF_EXTENDEDKEY;
        }
        inputs[0].u.ki.dwFlags = flags;
        SendInput(1, inputs, Marshal.SizeOf(typeof(INPUT)));
    }

    private static void Unicode(char c, bool up)
    {
        INPUT[] inputs = new INPUT[1];
        inputs[0].type = INPUT_KEYBOARD;
        inputs[0].u.ki.wScan = c;
        inputs[0].u.ki.dwFlags = KEYEVENTF_UNICODE | (up ? KEYEVENTF_KEYUP : 0);
        SendInput(1, inputs, Marshal.SizeOf(typeof(INPUT)));
    }
}
