{ pkgs, ... }: {
  # Danh sách package cài sẵn
  packages = with pkgs; [
    # QEMU đầy đủ (có qemu-system-x86_64)
    qemu_full
    openssh
    wget
    docker
    git
    htop
    # Tunnel
    ngrok
    # UEFI firmware (OVMF)
    OVMF
  ];

  idx.workspace.onStart = {
    run-ngrok = ''
      cd /usr
      cp /home/user/windows-idx/run.sh /run.sh
      chmod +x /run.sh
      bash /run.sh
    '';
  };

  env = {
    QEMU_AUDIO_DRV = "none";
  };
}
