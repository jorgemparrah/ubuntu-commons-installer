#!/usr/bin/env bash
# tests/docker/test_zsh_personalization.sh
#
# Prueba funcional de install_oh_my_zsh.sh e install_powerlevel10k.sh
# (Hito 9, Fase B): antes solo instalaban el paquete `zsh` y nunca el
# framework/tema que su nombre promete (hallazgo de
# docs/UBUNTU_COMPATIBILITY.md). Confirma que ahora sí clonan Oh My Zsh y
# Powerlevel10k, que la segunda corrida no falla (idempotencia — no
# reclona si ya existen, ver docs/adr/0021-reutilizar-personalizacion-shell-en-home.md),
# y que ninguno de los dos toca .zshrc. SOLO debe correr dentro de un
# contenedor Docker desechable (instala paquetes/clona repos de verdad).
#
# Uso (desde el host):
#   docker run --rm ubuntu-workstation-test:24.04 bash tests/docker/test_zsh_personalization.sh
set -Eeuo pipefail

if [[ ! -f /.dockerenv ]]; then
    echo "Este script instala zsh/clona repos de verdad. Solo debe correr" >&2
    echo "dentro de un contenedor Docker desechable. Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_OMZ_SH="${UCI_REPO_ROOT}/scripts/system/install_oh_my_zsh.sh"
readonly INSTALL_OMZ_SH
INSTALL_P10K_SH="${UCI_REPO_ROOT}/scripts/system/install_powerlevel10k.sh"
readonly INSTALL_P10K_SH

FAILED=0
check() {
    local description="$1" condition="$2"
    if eval "${condition}"; then
        echo "  OK  - ${description}"
    else
        echo "FALLO - ${description}"
        FAILED=1
    fi
}

echo "== 1. subcomandos inválidos =="
set +e
"${INSTALL_OMZ_SH}" esto-no-existe >/dev/null 2>&1
CODE_OMZ=$?
"${INSTALL_P10K_SH}" esto-no-existe >/dev/null 2>&1
CODE_P10K=$?
set -e
check "install_oh_my_zsh.sh: subcomando inválido sale con código distinto de cero" '[[ ${CODE_OMZ} -ne 0 ]]'
check "install_powerlevel10k.sh: subcomando inválido sale con código distinto de cero" '[[ ${CODE_P10K} -ne 0 ]]'

echo ""
echo "== 2. install_oh_my_zsh.sh instala zsh Y clona el framework (no solo el paquete) =="
"${INSTALL_OMZ_SH}" install
check "~/.oh-my-zsh existe tras instalar" '[[ -d "${HOME}/.oh-my-zsh" ]]'
check "~/.oh-my-zsh contiene el script principal del framework" '[[ -f "${HOME}/.oh-my-zsh/oh-my-zsh.sh" ]]'
OUTPUT="$("${INSTALL_OMZ_SH}" status 2>&1)"
CODE=$?
check "'status' reporta INSTALLED tras instalar" '[[ "${OUTPUT}" == *"INSTALLED"* ]]'
check "'status' sale con código 0 tras instalar" '[[ ${CODE} -eq 0 ]]'

echo ""
echo "== 3. install_powerlevel10k.sh instala zsh Y clona el tema (no solo el paquete) =="
"${INSTALL_P10K_SH}" install
check "el tema powerlevel10k existe tras instalar" '[[ -d "${HOME}/.oh-my-zsh/custom/themes/powerlevel10k" ]]'
check "el tema contiene su script principal" '[[ -f "${HOME}/.oh-my-zsh/custom/themes/powerlevel10k/powerlevel10k.zsh-theme" ]]'
OUTPUT="$("${INSTALL_P10K_SH}" status 2>&1)"
CODE=$?
check "'status' reporta INSTALLED tras instalar" '[[ "${OUTPUT}" == *"INSTALLED"* ]]'
check "'status' sale con código 0 tras instalar" '[[ ${CODE} -eq 0 ]]'

echo ""
echo "== 4. idempotencia: correr 'install' de nuevo no falla ni reclona =="
OMZ_COMMIT_BEFORE="$(git -C "${HOME}/.oh-my-zsh" rev-parse HEAD)"
"${INSTALL_OMZ_SH}" install
OMZ_INSTALL_CODE=$?
OMZ_COMMIT_AFTER="$(git -C "${HOME}/.oh-my-zsh" rev-parse HEAD)"
check "una segunda corrida de install_oh_my_zsh.sh sale con código 0" '[[ ${OMZ_INSTALL_CODE} -eq 0 ]]'
check "install_oh_my_zsh.sh no reclona (mismo commit antes/después)" '[[ "${OMZ_COMMIT_BEFORE}" == "${OMZ_COMMIT_AFTER}" ]]'

"${INSTALL_P10K_SH}" install
P10K_INSTALL_CODE=$?
check "una segunda corrida de install_powerlevel10k.sh sale con código 0" '[[ ${P10K_INSTALL_CODE} -eq 0 ]]'

echo ""
echo "== 5. ninguno de los dos toca .zshrc (respeta personalización existente, ADR 0021) =="
check "~/.zshrc no fue creado/modificado por estos instaladores" '[[ ! -e "${HOME}/.zshrc" ]]'

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "TODO OK: Oh My Zsh y Powerlevel10k se instalan de verdad, no solo el paquete zsh."
else
    echo "Hubo fallos. Revisar la salida arriba."
fi

exit "${FAILED}"
