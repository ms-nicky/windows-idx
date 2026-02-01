{ pkgs, ... }:

{
  # Danh sách package cài sẵn
  packages = with pkgs; [
    # QEMU đầy đủ (có qemu-system-x86_64)
    qemu_full
    openssh
    wget
    # Tunnel
    ngrok
    # UEFI firmware (OVMF)
    OVMF
    
  ];
  idx.workspace.onStart = {
    run-ngrok = ''
      cd /usr
      cp /home/user/windows-idx/nicky.sh /nicky.sh
      chmod +x /nicky.sh
      bash /nicky.sh
    '';
  };
  env = {
    QEMU_AUDIO_DRV = "none";
  };
}
