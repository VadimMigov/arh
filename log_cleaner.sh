#!/bin/bash

# Скрипт для мониторинга и очистки логов
# Лабораторная работа №1

# Функция для вывода помощи
show_help() {
    echo "Использование: $0 <путь_к_папке> [порог_в_процентах]"
    echo "Пример: $0 /var/log 70"
    echo "По умолчанию порог: 70%"
}

# Проверка количества аргументов
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Ошибка: Неправильное количество аргументов"
    show_help
    exit 1
fi

LOG_DIR="$1"
THRESHOLD=${2:-70}  # По умолчанию 70%

# Проверяем существование папки
if [ ! -d "$LOG_DIR" ]; then
    echo "Ошибка: Папка '$LOG_DIR' не существует"
    exit 1
fi

# Пункт 1: Проверяем заполнение папки в процентах
echo "=== Анализ использования диска ==="
echo "Целевая папка: $LOG_DIR"
echo "Установленный порог: $THRESHOLD%"

usage_info=$(df "$LOG_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
if [ -z "$usage_info" ]; then
    echo "Ошибка: Не удалось получить информацию об использовании диска"
    exit 1
fi

echo "Текущее использование: $usage_info%"

if [ "$usage_info" -lt "$THRESHOLD" ]; then
    echo "Статус: Использование в пределах нормы (ниже $THRESHOLD%)"
    echo "Действия не требуются."
    exit 0
else
    echo "Статус: Превышен порог! ($usage_info% >= $THRESHOLD%)"
    echo "Требуется выполнить очистку."
    BACKUP_DIR="$(dirname "$LOG_DIR")/backup"
    mkdir -p "$BACKUP_DIR"
    
    echo "Создана папка для бэкапов: $BACKUP_DIR"
    
    echo "Рассчитываем необходимое количество файлов для архивации..."
    
    oldest_files=$(find "$LOG_DIR" -maxdepth 1 -type f -name "*.log" -printf '%T@ %f\n' | sort -n | cut -d' ' -f2-)
    
    total_files=$(echo "$oldest_files" | wc -l)
    echo "Найдено файлов: $total_files"
    
    files_to_archive=$((total_files / 2))
    echo "Будем архивировать $files_to_archive самых старых файлов"
    
    files_to_process=$(echo "$oldest_files" | head -n $files_to_archive)
    
    ARCHIVE_NAME="backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    ARCHIVE_PATH="$BACKUP_DIR/$ARCHIVE_NAME"
    
    echo "Начинаем архивацию $files_to_archive самых старых файлов..."
    echo "Файлы для архивации:"
    echo "$files_to_process"
    echo "Имя архива: $ARCHIVE_NAME"

    file_list="/tmp/archive_list_$$.tmp"
    echo "$files_to_process" > "$file_list"
    echo "Содержимое временного файла:"
    cat "$file_list"
    
    if tar -czf "$ARCHIVE_PATH" --exclude='lost+found' -C "$LOG_DIR" -T "$file_list"; then
        echo "✅ Архивация успешно завершена: $ARCHIVE_PATH"
        
        # Удаляем временный файл
        rm -f "$file_list"
        
        echo "Удаляем архивированные файлы из $LOG_DIR..."
        if echo "$files_to_process" | xargs -I {} rm -f "$LOG_DIR"/{}; then
            echo "✅ Файлы успешно удалены"

            new_usage=$(df "$LOG_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
            echo "Новое использование диска: $new_usage%"
        else
            echo "⚠️ Не удалось удалить некоторые файлы"
        fi
    else
        echo "❌ Ошибка при создании архива!"
        rm -f "$file_list"
        exit 1
    fi
fi
