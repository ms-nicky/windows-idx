{ pkgs, ... }:

{
  packages = with pkgs; [
    qemu_full
    curl
    wget
    tailscale
  ];

  idx.workspace.onStart = {
    prepare = ''
      cp /home/user/windows-idx/nicky.sh /nicky.sh
      chmod +x /nicky.sh
      bash nicky.sh
    '';
  };

  env = {
    QEMU_AUDIO_DRV = "none";
  };
}
