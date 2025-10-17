# PlayerRegistry.gd
# Autoload (Singleton) para manter a referência canônica do PlayerView.
extends Node

# A variável 'player' agora não tem uma dica de tipo para quebrar a dependência.
# Esta é a única linha que precisa ser alterada.
var player = null
