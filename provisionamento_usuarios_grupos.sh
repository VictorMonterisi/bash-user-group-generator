#!/bin/bash
#
# Criação de diretórios e usuários
# - Todos os diretórios criados serão de propriedade do root;
# - O diretório /publico será acessível a todos;
# - Cada diretório de departamento será acessível somente pelos usuários do seu respectivo grupo;
# - Nenhum outro usuário terá acesso aos diretórios de departamentos alheios.
#

# 0. Verifica se está sendo executado como root
if [[ $EUID -ne 0 ]]; then
  echo "Este script deve ser executado como root." >&2
  exit 1
fi

# 1. Definição de variáveis
PUBLIC_DIR="/publico"
declare -A DEPARTAMENTOS=(
  [GRP_ADM]="/adm"
  [GRP_VEN]="/ven"
  [GRP_SEC]="/sec"
)
CREATED_USERS=()

# 2. Cria o diretório público
mkdir -p "$PUBLIC_DIR" || { echo "Falha ao criar $PUBLIC_DIR" >&2; exit 1; }
chown root:root "$PUBLIC_DIR"
chmod 777 "$PUBLIC_DIR"

echo "/publico pronto: proprietário root:root, permissão 777"

# 3. Cria grupos e diretórios de cada departamento
for GRP in "${!DEPARTAMENTOS[@]}"; do
  DIR="${DEPARTAMENTOS[$GRP]}"

  # cria o grupo se não existir
  if ! getent group "$GRP" &>/dev/null; then
    groupadd "$GRP" || { echo "Falha ao criar grupo $GRP" >&2; exit 1; }
    echo "Grupo $GRP criado"
  else
    echo "Grupo $GRP já existe, pulando criação"
  fi

  # cria o diretório e ajusta proprietário e permissão
  mkdir -p "$DIR" || { echo "Falha ao criar $DIR" >&2; exit 1; }
  chown root:"$GRP" "$DIR"
  chmod 770 "$DIR"
  echo "Diretório $DIR pronto: root:$GRP, permissão 770"
  echo
 done

# 4. Loop interativo para criação de usuários
while true; do
  # a) pede o nome
  read -p "Digite o nome do novo usuário: " USERNAME
  if [[ -z "$USERNAME" ]]; then
    echo "Nome não pode ser vazio."; continue
  fi
  if [[ ! "$USERNAME" =~ ^[a-z0-9]+$ ]]; then
    echo "Apenas letras minúsculas e números são permitidos."; continue
  fi
  if id "$USERNAME" &>/dev/null; then
    echo "Usuário '$USERNAME' já existe. Escolha outro nome."; continue
  fi

  # b) escolhe o departamento
  echo "Escolha o departamento para '$USERNAME':"
  echo "  1) GRP_ADM"
  echo "  2) GRP_VEN"
  echo "  3) GRP_SEC"
  read -p "Opção [1-3]: " OPTION

  case "$OPTION" in
    1) GROUP="GRP_ADM" ;;
    2) GROUP="GRP_VEN" ;;
    3) GROUP="GRP_SEC" ;;
    *)
      echo "Opção inválida. Tente novamente."; continue
      ;;
  esac

  # c) define senha e cria o usuário
  read -s -p "Defina uma senha para $USERNAME: " PASS
  echo
  read -s -p "Confirme a senha: " PASS2
  echo
  if [[ "$PASS" != "$PASS2" ]]; then
    echo "Senhas não coincidem. Tente novamente."; continue
  fi

  useradd -m -s /bin/bash -G "$GROUP" "$USERNAME" || { echo "Falha ao criar usuário $USERNAME" >&2; continue; }
  echo "$USERNAME:$PASS" | chpasswd || { echo "Falha ao definir senha para $USERNAME" >&2; continue; }
  passwd -e "$USERNAME"

  echo "Usuário '$USERNAME' criado no grupo '$GROUP'."
  CREATED_USERS+=("$USERNAME")

  # d) pergunta se deseja continuar
  read -p "Deseja criar outro usuário? (s/n): " REPLY
  case "$REPLY" in
    [Nn]* )
      echo "Finalizando criação de usuários." ;;
    * )
      echo "Preparando próximo usuário..."; continue ;;
  esac
  break
done

# 5. Resumo final
if ((${#CREATED_USERS[@]})); then
  echo
  echo "Usuários criados neste provisionamento: ${CREATED_USERS[*]}"
else
  echo
  echo "Nenhum usuário foi criado." 
fi

echo "Provisionamento concluído com sucesso!"
