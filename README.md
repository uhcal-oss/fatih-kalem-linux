# Fatih Kalem for Linux (Fedora, Ubuntu, Debian, Arch)

[English](#english) | [Türkçe](#türkçe)

---

## Türkçe

MEB ve EBA'nın popüler akıllı tahta kalem uygulaması **Fatih Kalem**'in modern Linux dağıtımlarında (Fedora, Debian, Ubuntu, Pardus, Arch) ve özellikle **Faz 1 / Faz 2 Etkileşimli Tahtalar** üzerinde sorunsuz çalışmasını sağlayan otomatik kurulum ve uyumluluk paketi.

### 🎯 Çözülen Sorunlar & Teknik Detaylar

Fatih Kalem, Windows Presentation Foundation (.NET 4.5 WPF) tabanlı bir 32-bit uygulamadır. Standart Wine altında çalıştırıldığında şu nedenlerle çöker:

1. **Eksik WPF MilCore / MilUtility_PathGeometryBounds**:
   Wine-Mono'nun dahili `wpfgfx_cor3.dll` kütüphanesi Microsoft WPF'in temel grafik fonksiyonlarını eksik barındırdığı için `System.EntryPointNotFoundException` veya `UCEERR_RENDERTHREADFAILURE` (0x88980406) hatası verip açılışta kapanır.
   - **Çözüm**: Microsoft .NET Core resmi çalışma zamanından tam uyumlu `wpfgfx_cor3.dll`, dokunmatik/kalem modülü `PenImc_cor3.dll` ve `D3DCompiler_47_cor3.dll` Wine-Mono ortamına entegre edilmiştir.

2. **Intel HD Graphics 3000 (Sandy Bridge) & DXVK Çökmesi**:
   Faz 1 akıllı tahtalarda bulunan 2. Nesil Intel Core i3/i5 işlemcilerdeki Intel HD Graphics 3000 GPU'nun donanımsal Vulkan desteği yoktur. Fedora gibi güncel dağıtımlar Direct3D için DXVK'yı varsayılan yaptığı için GPU `llvmpipe` (CPU simülasyonu) üzerinden çalışmaya zorlanır ve çöker.
   - **Çözüm**: Kurulum betiği Direct3D alternatiflerini Intel HD 3000'in tam donanım hızlandırma sağladığı yerel Mesa OpenGL (WineD3D) motoruna yönlendirir.

3. **Faz 1 IRTOUCH Dokunmatik Sürücüsü (`6615:0c20`)**:
   Faz 1 akıllı tahtaların kızılötesi dokunmatik çerçevesi modern Linux çekirdeklerinde varsayılan olarak çalışmaz.
   - **Çözüm**: Çekirdek uyumlu `OpticalDrv.ko` modülü ve `eta-touchdrv.service` otomatik olarak kurulur ve başlatılır.

---

### 🚀 Hızlı Kurulum

1. Depoyu klonlayın veya indirin:
   ```bash
   git clone https://github.com/yazilimodasi/fatih-kalem-linux.git
   cd fatih-kalem-linux
   ```

2. Kurulum betiğini çalıştırın:
   ```bash
   ./install.sh
   ```
   *(Sistem dosyalarını ve kütüphaneleri yüklemek için sudo şifreniz istenecektir.)*

3. `fatihkalem_setup.exe` dosyanız varsa `Downloads/` klasörüne veya depo dizinine koyabilirsiniz; bulunamazsa betik otomatik olarak MEB resmi sunucularından indirmeyi deneyecektir.

---

### 🖥️ Uygulamayı Başlatma

Kurulum tamamlandıktan sonra Fatih Kalem'i 3 farklı şekilde başlatabilirsiniz:
1. **Masaüstü Kısayolu**: Masaüstündeki **Fatih Kalem** simgesine çift tıklayın.
2. **Uygulamalar Menüsü**: Sistem menüsünde "Fatih Kalem" araması yapıp açın.
3. **Terminal**:
   ```bash
   fatih-kalem
   ```

---

### 🗑️ Kaldırma

Uygulamayı ve sistem entegrasyonlarını tamamen kaldırmak için:
```bash
./uninstall.sh
```

---

<a name="english"></a>
## English

Automated installer and compatibility layer to run **Fatih Kalem** (MEB / EBA interactive whiteboard pen application) on modern Linux distributions (Fedora, Debian, Ubuntu, Pardus, Arch) and interactive smart boards (Faz 1 / Faz 2).

### 🎯 Key Fixes
- **WPF Native MilCore Integration**: Patches Wine-Mono with genuine Microsoft WPF Core runtime DLLs (`wpfgfx_cor3.dll`, `PenImc_cor3.dll`, `D3DCompiler_47_cor3.dll`) to eliminate `EntryPointNotFoundException` and render thread failures.
- **Intel HD 3000 Compatibility**: Bypasses DXVK / Vulkan on Sandy Bridge hardware and routes rendering through native hardware-accelerated OpenGL (WineD3D).
- **Faz 1 Smart Board Touch Driver**: Automatically detects and configures the `IRTOUCHSYSTEMS Optical TouchScreen` (`6615:0c20`) driver and systemd service.

### 🚀 Installation
```bash
git clone https://github.com/yazilimodasi/fatih-kalem-linux.git
cd fatih-kalem-linux
./install.sh
```

### 🖥️ Running
- Launch from your desktop shortcut, application menu, or run:
  ```bash
  fatih-kalem
  ```

---

### 📄 Lisans
Bu proje eğitim amaçlı geliştirilmiş olup MEB ve EBA tarafından sunulan Fatih Kalem yazılımının Linux ortamında çalıştırılabilmesi için uyumluluk köprüsü sunar.
