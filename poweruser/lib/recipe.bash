#!/usr/bin/env bash
set -Eeuo pipefail

load_recipe() {
    local recipe_name="${1}"
    local recipe_file="${POWERUSER_DIR}/recipes/${recipe_name}.sh"
    [[ -f "${recipe_file}" ]] || die "Recipe not found: ${recipe_name}"

    pkgname='' pkgver='' pkgrel='' desc='' url=''
    sources=() depends=() makedepends=() feature_flags=() provides=()
    unset -f prepare configure build check package 2>/dev/null || true

    source "${recipe_file}"

    [[ -n "${pkgname}" ]] || die "Recipe ${recipe_name} missing pkgname"
    [[ -n "${pkgver}" ]]  || die "Recipe ${recipe_name} missing pkgver"
    [[ -n "${pkgrel}" ]]  || die "Recipe ${recipe_name} missing pkgrel"

    depends=("${depends[@]:-}")
    makedepends=("${makedepends[@]:-}")
    feature_flags=("${feature_flags[@]:-}")
    provides=("${provides[@]:-}")

    export pkgname pkgver pkgrel desc url sources depends makedepends feature_flags provides
}

list_recipes() {
    local recipe
    for recipe in "${POWERUSER_DIR}"/recipes/*.sh; do
        [[ -f "${recipe}" ]] || continue
        local name
        name="$(basename "${recipe}" .sh)"
        [[ "${name}" == "template" ]] && continue
        local d
        d="$(grep -m1 '^desc=' "${recipe_file}" | cut -d'"' -f2)"
        printf '%s — %s\n' "${name}" "${d:-no description}"
    done
}