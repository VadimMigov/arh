#!/bin/bash

# Скрипт тестирования для log_cleaner.sh
# Лабораторная работа №1

echo "=== ЗАПУСК ТЕСТИРОВАНИЯ ==="

# Создаем тестовые папки
TEST_DIR="./test_env"
LOG_DIR="$TEST_DIR/log"
BACKUP_DIR="$TEST_DIR/backup"
SCRIPT_PATH="./log_cleaner.sh"

# Очищаем старые тестовые данные
echo "Очищаем старые тестовые данные..."
rm -rf "$TEST_DIR"

# Создаем папки
mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"

# Проверяем есть ли основной скрипт
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ ОШИБКА: Основной скрипт $SCRIPT_PATH не найден!"
    echo "Создайте сначала log_cleaner.sh в этой же папке"
    exit 1
fi

# Даем права на выполнение
chmod +x "$SCRIPT_PATH"

# Функция для создания тестовых файлов
create_test_files() {
    echo "Создаем тестовые файлы..."
    
    # Создаем 10 файлов по 100MB каждый (итого ~1GB)
    for i in {1..10}; do
        # Создаем файл с случайными данными
        dd if=/dev/urandom of="${LOG_DIR}/logfile_${i}.log" bs=1M count=100 status=none 2>/dev/null
        
        # Устанавливаем разное время создания (старые файлы)
        touch -d "$i days ago" "${LOG_DIR}/logfile_${i}.log"
        
        echo "Создан файл: logfile_${i}.log (100MB)"
    done
    
    echo "Тестовые файлы созданы!"
    echo "Общий размер: $(du -sh $LOG_DIR | cut -f1)"
}

# Функция запуска одного теста
run_test() {
    local test_name="$1"
    local threshold="$2"
    local use_lzma="$3"
    
    echo ""
    echo "=== ТЕСТ: $test_name ==="
    echo "Порог: ${threshold}%"
    
    # Очищаем и создаем файлы заново
    rm -rf "$LOG_DIR"/*
    rm -rf "$BACKUP_DIR"/*
    create_test_files
    
    # Настраиваем сжатие если нужно
    if [ "$use_lzma" = "1" ]; then
        export LAB1_MAX_COMPRESSION=1
        echo "Используется LZMA сжатие"
    else
        unset LAB1_MAX_COMPRESSION
    fi
    
    # Запускаем основной скрипт
    echo "Запускаем скрипт очистки..."
    if [ "$use_lzma" = "1" ]; then
        LAB1_MAX_COMPRESSION=1 "$SCRIPT_PATH" --path "$LOG_DIR" --threshold "$threshold" --backup-dir "$BACKUP_DIR"
    else
        "$SCRIPT_PATH" --path "$LOG_DIR" --threshold "$threshold" --backup-dir "$BACKUP_DIR"
    fi
    
    # Проверяем результат
    local backup_files=$(ls "$BACKUP_DIR"/*.tar.* 2>/dev/null | wc -l)
    local remaining_files=$(ls "$LOG_DIR"/*.log 2>/dev/null | wc -l)
    
    echo "Результат:"
    echo "- Создано архивов: $backup_files"
    echo "- Осталось файлов: $remaining_files"
    
    # Проверяем успешность теста
    if [ $backup_files -gt 0 ]; then
        echo "✅ ТЕСТ ПРОЙДЕН"
        return 0
    else
        echo "❌ ТЕСТ ПРОВАЛЕН"
        return 1
    fi
}

# Запускаем все тесты
echo "Подготовка тестового окружения..."
create_test_files

passed_tests=0
total_tests=4

# Тест 1: Базовый тест
if run_test "Базовый тест (порог 70%)" "70" "0"; then
    ((passed_tests++))
fi

# Тест 2: Низкий порог
if run_test "Низкий порог (50%)" "50" "0"; then
    ((passed_tests++))
fi

# Тест 3: Высокий порог  
if run_test "Высокий порог (90%)" "90" "0"; then
    ((passed_tests++))
fi

# Тест 4: LZMA сжатие
if run_test "LZMA сжатие (порог 70%)" "70" "1"; then
    ((passed_tests++))
fi

# Итоги
echo ""
    echo "=== ИТОГИ ТЕСТИРОВАНИЯ ==="
echo "Пройдено тестов: $passed_tests/$total_tests"

# Очистка
rm -rf "$TEST_DIR"

if [ $passed_tests -eq $total_tests ]; then
    echo "✅ ВСЕ ТЕСТЫ ПРОЙДЕНЫ!"
    exit 0
else
    echo "❌ ЕСТЬ ПРОВАЛЕННЫЕ ТЕСТЫ"
    exit 1
fi
