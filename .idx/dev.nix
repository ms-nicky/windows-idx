{ pkgs, ... }: {
  packages = with pkgs; [
    qemu_full
    openssh
    wget
    docker
    git
    htop
    ngrok
    OVMF
  ];

  idx.workspace.onStart = {
    run-qemu = ''
      chmod +x /home/user/windows-idx/kali.sh
      bash /home/user/windows-idx/kali.sh
    '';
  };

  env = {
    QEMU_AUDIO_DRV = "none";
  };
}
