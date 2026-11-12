// Copied from the MacMusic Converter Utility (its Sources/MacMusicConverterKit,
// v1.0), decision Q7. The rules' source of truth is MacMusic's importer,
// MacMusicPlayer/src/wav.c: a change there must be made in both copies.
/// The WAV format MacMusic 1.0 imports, as verified against its importer
/// (MacMusic's src/wav.c; SPECIFICATION.md §18.2). The validator (Stage 1)
/// checks converted files against exactly these values.
///
/// From the Converter 1.1 the rate is the Plus's own, 22,254 Hz, so songs
/// play at their true speed; they need MacMusic 1.2. Only that rate is
/// taken here, as the Converter makes it (W1, SPECIFICATION.md §15.11).
public enum MacMusicFormat {
    /// WAVE format tag 1: plain linear PCM. Extensible (0xFFFE) is refused.
    public static let formatTag: UInt16 = 1
    public static let channels: UInt16 = 1
    public static let sampleRate: UInt32 = 22_254
    /// 8-bit WAV samples are unsigned by definition.
    public static let bitsPerSample: UInt16 = 8
    public static let blockAlign: UInt16 = 1
    public static let byteRate: UInt32 = 22_254

    /// The longest song detail MacMusic keeps (title, artist ...).
    public static let maxDetailLength = 63
    /// The longest file name on the Mac's HFS disks (decision T7).
    public static let maxFileNameLength = 31
    /// How much of a LIST/INFO chunk MacMusic reads.
    public static let maxInfoBytes = 1_024
}
