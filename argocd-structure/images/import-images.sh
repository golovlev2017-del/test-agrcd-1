#!/bin/bash
# Скрипт для импорта Docker образов в локальный registry (offline)
# Использование: ./import-images.sh <путь к tar файлу> <registry URL>

set -e

REGISTRY_URL="${1:-harbor.local.test:8443}"
IMAGES_TAR="${2:-all-images.tar}"

echo "=== Импорт образов в локальный registry ==="
echo "Registry: $REGISTRY_URL"
echo "Images archive: $IMAGES_TAR"

# Проверка наличия файла
if [ ! -f "$IMAGES_TAR" ]; then
    echo "Ошибка: файл $IMAGES_TAR не найден"
    exit 1
fi

# Загрузка образов из tar
echo "Загрузка образов из $IMAGES_TAR..."
docker load -i "$IMAGES_TAR"

# Список всех загруженных образов
echo "Получение списка образов..."
IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "^<none>")

echo "Найдено образов: $(echo "$IMAGES" | wc -l)"

# Retag и push в локальный registry
for image in $IMAGES; do
    # Извлекаем имя образа без registry
    image_name=$(echo "$image" | sed 's|^[^/]*:||')
    
    # Формируем новое имя для локального registry
    new_image="$REGISTRY_URL/library/$image_name"
    
    echo "Processing: $image -> $new_image"
    
    # Retag
    docker tag "$image" "$new_image"
    
    # Push (раскомментировать для реальной загрузки)
    # docker push "$new_image"
    
    echo "  ✓ Tagged: $new_image"
done

echo ""
echo "=== Готово! ==="
echo "Для загрузки образов в registry выполните:"
echo "  docker push $REGISTRY_URL/library/<image_name>"
echo ""
echo "Или раскомментируйте строку с docker push в этом скрипте"
