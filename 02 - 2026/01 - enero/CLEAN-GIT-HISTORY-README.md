# 🧹 Script de Limpieza de Historial Git

Script para reducir el tamaño de repositorios Git eliminando archivos grandes del historial completo.

## ⚠️ ADVERTENCIAS IMPORTANTES

- **Este script reescribe el historial de Git permanentemente**
- **Asegúrate de tener un backup completo antes de ejecutarlo**
- **Si ya hiciste push a GitHub, necesitarás hacer force push después**
- **Avisa a tu equipo antes de hacer force push en repositorios compartidos**

## 📋 Requisitos Previos

1. Identifica los archivos/directorios grandes en tu repositorio:
   ```bash
   git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | awk '/^blob/ {print substr($0,6)}' | sort -k2 -n -r | head -20
   ```

2. Verifica el tamaño actual:
   ```bash
   du -sh .git
   git count-objects -vH
   ```

## 🚀 Uso

1. **Edita el script** y agrega las rutas de archivos/directorios a eliminar en la sección `ARCHIVOS A ELIMINAR`:
   ```bash
   nano clean-git-history.sh
   # O usa tu editor favorito
   ```

2. **Ejecuta el script**:
   ```bash
   chmod +x clean-git-history.sh
   ./clean-git-history.sh
   ```

3. **Verifica el resultado**:
   ```bash
   du -sh .git
   git count-objects -vH
   ```

4. **Si todo está bien, haz push** (solo si ya habías hecho push antes):
   ```bash
   git push origin --force --all
   git push origin --force --tags
   ```

## 📝 Ejemplo de Configuración

```bash
ARCHIVOS_A_ELIMINAR=(
    "node_modules/"
    "dist/"
    "*.pdf"
    "archivos-grandes/"
    "carpeta/subcarpeta/"
)
```

## 🔄 Restaurar desde Backup

Si algo sale mal, puedes restaurar desde el backup creado automáticamente:

```bash
git checkout backup-before-cleanup
```

## 💡 Tips

- **Identifica archivos grandes primero**: Usa el comando de requisitos previos
- **Prueba en un branch de prueba**: Crea un branch de prueba antes de limpiar master
- **Considera usar Git LFS**: Para archivos grandes que necesitas mantener en el futuro
- **Actualiza .gitignore**: Para prevenir que archivos grandes se agreguen de nuevo

## 🐛 Solución de Problemas

### Error: "Cannot rewrite branches: You have unstaged changes"
```bash
git stash
./clean-git-history.sh
git stash pop
```

### El push falla con HTTP 400
- Verifica protecciones de branch en GitHub
- Considera usar SSH en lugar de HTTPS
- Reduce el tamaño del pack si es muy grande

### El proceso es muy lento
- Es normal para repositorios grandes
- Puede tomar varios minutos dependiendo del tamaño
- El script muestra progreso durante la ejecución

## 📚 Recursos Adicionales

- [Git Filter-Branch Documentation](https://git-scm.com/docs/git-filter-branch)
- [Git Filter-Repo (alternativa más moderna)](https://github.com/newren/git-filter-repo)
- [GitHub: Reducing Repository Size](https://docs.github.com/en/repositories/working-with-files/managing-large-files/removing-files-from-a-repositorys-history)

## 📄 Licencia

Este script es de dominio público. Úsalo libremente.

## 🤝 Contribuciones

Mejoras y sugerencias son bienvenidas. Este script es una herramienta de la comunidad open source.

