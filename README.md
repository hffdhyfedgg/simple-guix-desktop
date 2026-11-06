

Собираю свой образ для установки guix. Произвёл тестовую сборку, сейчас буду делать итогову (беловую).

Сборка состоит из двух основных частей:
1. Замыкание системы. Файл `for_flight/config/configuration.scm` использовался с `guix time-machine -C for_flight/channels.scm -- system build for_flight/config/configuration.scm`. Далее это замыкание упаковывается в `.nar`: 
```
guix archive --export --recursive /gnu/store/***-system > system-closure.nar
```
После используем `scripts/make-nar-parts.sh`. Части архива оказываются в `for_flight/nars`.
2. Установочный образ. Он должен содержать в себе всё необходимое для установки на борту. Все файлы для целевой системы должны будут импортированы в `/gnu/store` из `nars` и система должна установиться полностью без зависимотей.

Каналы в `channels.scm` должны указывать на локальные копии репозиториев. Я их положу в `for_flight`, оттуда они попадут в iso. Там будут лежать только состояния конкретных коммитов -- для экономии места.

---
```sh
# 1. На машине сборки: экспортируем closure системы в NAR
guix archive --export --recursive \
  /gnu/store/1lnp54v9i2h6wdwyj8laj3m1yw17gdif-system \
  > system-closure.nar

# 2. Включаем NAR в ISO через локальный пакет
# (как показал предыдущий ассистент)

# 3. На целевой машине (из ISO-установщика): импортируем
guix archive --import < /path/to/system-closure.nar
```


```sh
# Собираем ISO с включённым замыканием
guix system image --image-type=iso9660 \
  installer.scm
```
---

### Как сделать репозиторий с 1 коммитом

```sh
# 1. Создаем пустой локальный репозиторий
mkdir -p ~/src/nonguix-shallow && cd ~/src/nonguix-shallow
git init

# 2. Добавляем удаленный репозиторий
git remote add origin https://codeberg.org/guix/guix.git

# 3. Извлекаем только нужный коммит с глубиной 1
git fetch --depth=1 origin 9edb3f66fd807b096b48283debdcddccfea34bad

# 4. Переключаемся на этот коммит
git checkout FETCH_HEAD
```
