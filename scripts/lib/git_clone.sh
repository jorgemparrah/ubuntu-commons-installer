#!/usr/bin/env bash
# scripts/lib/git_clone.sh
#
# Helpers compartidos para instaladores que clonan un repositorio Git
# oficial directamente (Hito 11, grupo git-clone: Oh My Zsh,
# Powerlevel10k), en vez de correr el script remoto de instalación de
# cada proyecto. Hermano de scripts/lib/apt.sh/snap.sh/apt_vendor_repo.sh/
# deb_direct.sh para este mecanismo.
#
# Nota de la migración: a diferencia de lo que su nombre podría sugerir,
# ninguno de los 2 instaladores de este grupo instala Oh My Zsh vía el
# script `install.sh` oficial (que se ejecuta con `curl | sh` y modifica
# `.zshrc`/el shell por defecto); ambos ya clonaban el repo directamente
# con `git clone --depth=1`, precisamente para no tocar la personalización
# existente al reutilizar `/home` (ver
# docs/adr/0021-reutilizar-personalizacion-shell-en-home.md). Esta
# biblioteca solo centraliza esa lógica ya existente, sin cambiarla.
#
# Pensado para cargarse con `source`; no declara su propio modo estricto
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md). El script
# que lo sourcea es responsable de `set -Eeuo pipefail`.

if [[ "${UCI_GIT_CLONE_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_GIT_CLONE_SH_LOADED=1

# git_clone_present <dest_dir>
# 0 si <dest_dir> es un repositorio Git válido (tiene '.git'); 1 si no
# existe o quedó corrupto/incompleto (por ejemplo, un 'git clone'
# interrumpido a mitad de camino).
git_clone_present() {
    local dest_dir="$1"
    [[ -d "${dest_dir}/.git" ]]
}

# git_clone_ensure <repo_url> <dest_dir>
# Clona <repo_url> en <dest_dir> con '--depth=1' (historial superficial,
# no se necesita el historial completo para un framework/tema de shell).
# Si <dest_dir> ya es un repositorio Git válido, no hace nada (idempotente
# — no reclona sobre una instalación ya presente, para no perder cambios
# locales que la persona usuaria pudiera haber hecho).
git_clone_ensure() {
    local repo_url="$1" dest_dir="$2"

    if git_clone_present "${dest_dir}"; then
        echo "${dest_dir} ya es un repositorio Git válido, no se reclona."
        return 0
    fi

    mkdir -p "$(dirname "${dest_dir}")"
    git clone --depth=1 "${repo_url}" "${dest_dir}"
}

# git_clone_update <dest_dir>
# 'git pull --ff-only': solo avanza si el historial remoto es un
# fast-forward directo del local, nunca fusiona ni reescribe commits
# locales (relevante si la persona usuaria llegó a modificar el clon).
git_clone_update() {
    local dest_dir="$1"
    git -C "${dest_dir}" pull --ff-only
}
