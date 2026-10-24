SET search_path TO hh_school;

-- ЗАДАНИЕ 1. Аудит качества данных
-- Проверка можно ли связать событие с откликом
-- Звонки без response_id:
SELECT
    call_id,
    COUNT(*) OVER () AS problem_count
FROM calls
WHERE response_id IS NULL;
-- Результат: 8 звонков (700244, 700245, 700246, 700247, 700248, 700249, 700250, 700251).

-- Звонки с response_id, которого нет в responses:
SELECT
    call_id,
    COUNT(*) OVER () AS problem_count
FROM calls c
LEFT JOIN responses r
    ON r.response_id = c.response_id
WHERE c.response_id IS NOT NULL
  AND r.response_id IS NULL;
-- Результат: 0.

-- Сообщения без response_id:
SELECT
    message_id,
    COUNT(*) OVER () AS problem_count
FROM messages
WHERE response_id IS NULL;
-- Результат: 0.

-- Сообщения с response_id, которого нет в responses:
SELECT
    message_id,
    COUNT(*) OVER () AS problem_count
FROM messages m
LEFT JOIN responses AS r
    ON r.response_id = m.response_id
WHERE m.response_id IS NOT NULL
  AND r.response_id IS NULL;
-- Результат: 0.

-- Согласованы ли идентификаторы события и отклика:
-- vacancy_id звонка не совпадает с vacancy_id отклика:
SELECT
    call_id,
    COUNT(*) OVER () AS problem_count
FROM calls c
JOIN responses r
    ON r.response_id = c.response_id
WHERE c.vacancy_id IS DISTINCT FROM r.vacancy_id;
-- Результат: 0.

-- Работодатель звонка не совпадает с работодателем вакансии отклика:
SELECT
    c.call_id,
    COUNT(*) OVER () AS problem_count
FROM calls c
JOIN responses r
    ON r.response_id = c.response_id
JOIN vacancies v
    ON v.vacancy_id = r.vacancy_id
WHERE c.employer_id IS DISTINCT FROM v.employer_id;
-- Результат: 0.

-- applicant_id звонка не совпадает с resume_id отклика:
SELECT
    c.call_id,
    COUNT(*) OVER () AS problem_count
FROM calls c
JOIN responses r
    ON r.response_id = c.response_id
WHERE c.applicant_id IS DISTINCT FROM r.resume_id;
-- Результат: 0.

-- vacancy_id сообщения не совпадает с vacancy_id отклика:
SELECT
    message_id,
    COUNT(*) OVER () AS problem_count
FROM messages m
JOIN responses r
    ON r.response_id = m.response_id
WHERE m.vacancy_id IS DISTINCT FROM r.vacancy_id;
-- Результат: 0.

-- Работодатель сообщения не совпадает с работодателем вакансии отклика:
SELECT
    message_id,
    COUNT(*) OVER () AS problem_count
FROM messages m
JOIN responses r
    ON r.response_id = m.response_id
JOIN vacancies v
    ON v.vacancy_id = r.vacancy_id
WHERE m.employer_id IS DISTINCT FROM v.employer_id;
-- Результат: 0.

-- applicant_id сообщения не совпадает с resume_id отклика:
SELECT
    message_id,
    COUNT(*) OVER () AS problem_count
FROM messages m
JOIN responses r
    ON r.response_id = m.response_id
WHERE m.applicant_id IS DISTINCT FROM r.resume_id;
-- Результат: 0.

-- Положение события во времени относительно отклика
-- Звонок раньше создания отклика:
SELECT
    call_id,
    COUNT(*) OVER () AS problem_count
FROM calls c
JOIN responses r
    ON r.response_id = c.response_id
WHERE call_at < created_at;
-- Результат: 0.

-- Сообщение раньше создания отклика:
SELECT
    message_id,
    COUNT(*) OVER () AS problem_count
FROM messages m
JOIN responses r
    ON r.response_id = m.response_id
WHERE sent_at < created_at;
-- Результат: 0.

-- Звонок позже 7 суток после отклика:
-- Не является ошибкой, однако анализ в задании проводится зачастую в 7-дневном интервале,
-- поэтому, посмотрим, сколько таких значений есть в таблице.
SELECT
    call_id,
    COUNT(*) OVER () AS problem_count
FROM calls c
JOIN responses r
    ON r.response_id = c.response_id
WHERE call_at > created_at + INTERVAL '7 days';
-- Результат: 75 звонков.

-- Сообщение позже 7 суток после отклика:
SELECT
    message_id,
    COUNT(*) OVER () AS problem_count
FROM messages m
JOIN responses r
    ON r.response_id = m.response_id
WHERE sent_at > created_at + INTERVAL '7 days';
-- Результат: 886 сообщений.

-- Проверка, согласованы ли значения внутри одной строки звонка.
-- Здесь может быть несколько случаев:
-- 1) status звонка не согласуется с call_duration.
-- 2) successful: длительность должна быть задана и больше нуля;
-- 3) unsuccessful/error: длительность должна отсутствовать.
SELECT
    call_id,
    COUNT(*) OVER () AS problem_count
FROM calls
WHERE status IS NULL
   OR status NOT IN ('successful', 'unsuccessful', 'error')
   OR (status = 'successful'
       AND (call_duration IS NULL OR call_duration <= 0))
   OR (status IN ('unsuccessful', 'error')
       AND call_duration IS NOT NULL);
-- Результат: 0.

-- status не согласуется с техническими тегами call_tags.
SELECT
    call_id,
    COUNT(*) OVER () AS problem_count
FROM calls
WHERE call_tags IS NULL
   OR status IS NULL
   OR NOT (
       (status = 'successful'
        AND 'connected' = ANY(call_tags)
        AND NOT ('no_answer' = ANY(call_tags))
        AND NOT ('technical_error' = ANY(call_tags)))
       OR
       (status = 'unsuccessful'
        AND 'no_answer' = ANY(call_tags)
        AND NOT ('connected' = ANY(call_tags))
        AND NOT ('technical_error' = ANY(call_tags)))
       OR
       (status = 'error'
        AND 'technical_error' = ANY(call_tags)
        AND NOT ('connected' = ANY(call_tags))
        AND NOT ('no_answer' = ANY(call_tags)))
   );
-- Результат: 0.

-- caller_role не согласуется с тегом inbound/outbound:
SELECT
    call_id,
    COUNT(*) OVER () AS problem_count
FROM calls
WHERE call_tags IS NULL
   OR caller_role IS NULL
   OR caller_role NOT IN ('employer', 'applicant')
   OR NOT (
       (caller_role = 'employer'
        AND 'outbound' = ANY(call_tags)
        AND NOT ('inbound' = ANY(call_tags)))
       OR
       (caller_role = 'applicant'
        AND 'inbound' = ANY(call_tags)
        AND NOT ('outbound' = ANY(call_tags)))
   );
-- Результат: 0.

-- Пропуски и необычные значения:

-- Звонки без длительности при статусе 'successful'.
-- Это является допустимым сценарием, подразумевается, что разговора не было
SELECT
    c.call_id,
    COUNT(*) OVER () AS problem_count
FROM calls AS c
WHERE c.call_duration IS NULL
  AND c.status <> 'successful';
-- Результат: 70 звонков. Влияет только на атрибут
-- длительности, не на факт коммуникации.

-- Звонки со статусом 'error':
SELECT
    c.call_id
FROM calls AS c
WHERE c.status = 'error';
-- Результат: 1 звонок, call_id 700163.

-- Сообщения с NULL или пустым текстом:
SELECT
    message_id,
    COUNT(*) OVER () AS problem_count
FROM messages
WHERE message_text IS NULL
   OR message_text = '';
-- Результат: 0.

-- Сообщения без значения is_read в JSONB (ключа нет или значение JSON null):
SELECT
    message_id,
    COUNT(*) OVER () AS problem_count
FROM messages
WHERE message_meta IS NULL
   OR (message_meta ->> 'is_read') IS NULL;
-- Результат: 0.

-- Сообщения без канала в JSONB:
SELECT
    message_id,
    COUNT(*) OVER () AS problem_count
FROM messages
WHERE message_meta IS NULL
   OR (message_meta ->> 'channel') IS NULL;
-- Результат: 0.

-- Сообщения, где вложения отсутствует или не является JSON-массивом.
SELECT
    message_id,
    COUNT(*) OVER () AS problem_count
FROM messages
WHERE message_meta IS NULL
   OR (message_meta -> 'attachments') IS NULL
   OR NOT ((message_meta -> 'attachments') @> '[]'::jsonb);
-- Результат: 0. Количество вложений можно посчитать через длина массива.

-- Дубликаты событий
-- Дубликаты звонков: кандидат, вакансия, роль и время.
SELECT
    d.call_id,
    d.dup_cnt AS duplicate_count
FROM (
    SELECT
        c.call_id,
        COUNT(*) OVER (
            PARTITION BY c.vacancy_id, c.applicant_id, c.caller_role, c.call_at
        ) AS dup_cnt
    FROM calls AS c
) AS d
WHERE d.dup_cnt > 1;
-- Результат: 0.

-- Дубликаты сообщений: отклик, отправитель, время и текст.
SELECT
    message_id,
    dup_cnt AS duplicate_count
FROM (
    SELECT
        m.message_id,
        COUNT(*) OVER (
            PARTITION BY m.response_id, m.sender_role, m.sent_at, m.message_text
        ) AS dup_cnt
    FROM messages AS m
)
WHERE dup_cnt > 1;
-- Результат: 0.

-- Длительность успешных звонков.
-- Рассмотрим строки, где длительность можно интерпретировать, то есть статус звонка 'successful',
-- значение длительности должно бть не NULL и > 0.
-- 3 успешных звонка без response_id остаются в выборке.
WITH successful_calls AS (
    SELECT
        call_id,
        call_duration
    FROM calls
    WHERE status = 'successful'
      AND call_duration IS NOT NULL
      AND call_duration > 0
),
p99 AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (
            ORDER BY call_duration
        ) AS p99_duration
    FROM successful_calls
)

SELECT
    COUNT(*) AS calls_cnt,
    ROUND(AVG(call_duration), 2) AS avg_duration,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
          ORDER BY call_duration)::numeric,2) 
          AS median_duration,
    ROUND(p.p99_duration::numeric, 2) AS p99_duration,
    COUNT(*) FILTER (WHERE call_duration > p.p99_duration) AS calls_above_p99,
    ROUND(AVG(call_duration) FILTER
    	 (WHERE call_duration <= p.p99_duration), 2)
    	 AS avg_without_above_p99,
    MIN(call_duration) AS min_duration,
    MAX(call_duration) AS max_duration
FROM successful_calls
CROSS JOIN p99 p
GROUP BY p.p99_duration;
-- Результат:
-- Количество звонков: 181
-- Средняя длительность: 467,28
-- Медиана длительности: 438
-- 99 перцентиль: 890,4
-- Количество звонков выше 99 перцентиля: 2
-- Среднее без 99 перцентиля: 462,49
-- Минимальная длительность: 51
-- Максимальная длительность: 899

-- Успешные звонки выше 99-го перцентиля:
WITH successful_calls AS (
    SELECT
        call_id,
        response_id,
        call_duration
    FROM calls
    WHERE status = 'successful'
      AND call_duration IS NOT NULL
      AND call_duration > 0
),
p99 AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (
            ORDER BY call_duration
        ) AS p99_duration
    FROM successful_calls
)
SELECT
    sc.call_id,
    sc.response_id,
    sc.call_duration
FROM successful_calls sc
CROSS JOIN p99 p
WHERE sc.call_duration > p.p99_duration
ORDER BY sc.call_duration DESC;
-- Результат: звонок 700199 (response_id 50610) - 899 с и звонок 700159 (response_id 50221) - 892 с.

-- Вывод:
-- Можно выделить следующие особенности данных:
-- 1) Единственная проблема, которая была выявлена, это 8 звонков без response_id. Проблема влияет на сам факт
-- коммуникации после конкретного отклика, поэтому эти звонки исключаем из анализа в дальнейших заданиях.
-- На длительность она не влияет, поэтому успешные звонки среди звонков без привязки к отклику
-- остаются в статистике длительности.

-- 2) Идентификаторы согласованы, несуществующих response_id нет,
-- событий раньше отклика нет, дубликатов нет.

-- 3) Значения внутри строк согласованы. Конфликтов status/call_duration, status/call_tags
-- и caller_role/call_tags нет. В сообщениях везде заполнены message_text, channel,
-- is_read и attachments.

-- 4) Можно выделить также случаи, которые являются допустимыми и отражают ту или иную ситуацию.
-- Так, 75 звонков и 886 сообщений произошли позже 7 суток после отклика. NULL-длительность у 70
-- звонков (69 unsuccessful и 1 error), то есть разговора не было, такие значения не требуют заполнения.
-- Один звонок со статусом 'error' (700163, технический сбой). Строка непротиворечива, в задании 2
-- его можно оставить как попытку связи со стороны работодателя.

-- 5) Длительность успешных звонков: среднее 467.28 с, медиана 438 с, P99 = 890.4 с,
-- выше P99 два звонка (700159: 892 с, 700199: 899 с), среднее без них 462.49 с.
-- Значения выше P99 считаем допустимыми. Два звонка сдвигают среднее всего на 4.8 с,
-- поэтому ничего не исключаем. При расчёте типичной длительности звонка можно использовать
-- медиану, которая не так исказится из-за выбросов.


-- ЗАДАНИЕ 2. Единый слой коммуникаций
-- Значения необходимо отфильтровать по следующим критериям:
-- 1) Только коммуникации работодателя.
-- 2) Только первые 7 суток после отклика.
-- 3) Событие привязывается к отклику только по response_id (JOIN responses).
-- Поэтому необходимо исключить 8 звонков без response_id, найденых в задании 1.
-- 4) Будут учитываться звонки берём с любым статусом.
-- пытка дозвониться считается как коммуникация со стороны работодателя.
-- 5) Гранулярность: одна строка = одно событие.

WITH employer_messages AS (
    SELECT
        m.response_id,
        m.employer_id,
        message_id AS event_id,
        sent_at AS event_at,
        'message' AS event_type
    FROM messages m
    JOIN responses r
        ON r.response_id = m.response_id
    WHERE sender_role = 'employer'
      AND sent_at BETWEEN created_at AND created_at + INTERVAL '7 days'
),
employer_calls AS (
    SELECT
        c.response_id,
        c.employer_id,
        call_id AS event_id,
        call_at AS event_at,
        'call' AS event_type
    FROM calls c
    JOIN responses r
        ON r.response_id = c.response_id
    WHERE caller_role = 'employer'
      AND call_at BETWEEN created_at AND created_at + INTERVAL '7 days'
),
events AS (
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM employer_messages
    UNION ALL
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM employer_calls
)
SELECT
    COUNT(*) AS events_cnt,
    COUNT(DISTINCT response_id) AS responses_with_communication_cnt,
    COUNT(*) FILTER (WHERE event_type = 'call') AS calls_cnt,
    COUNT(*) FILTER (WHERE event_type = 'message') AS messages_cnt
FROM events;

-- Контрольные значения:
-- 1) Общее количество событий: 1096
-- 2) Откликов с коммуникацией: 382
-- 3) Звонков: 108
-- 4) Сообщений: 988

-- ЗАДАНИЕ 3. Таймлайн коммуникаций и витрина отклика
-- CTE повторяются для удобства проверки

-- 1. Слой уровня события:
WITH employer_messages AS (
    SELECT
        m.response_id,
        m.employer_id,
        message_id AS event_id,
        sent_at AS event_at,
        'message' AS event_type
    FROM messages m
    JOIN responses r
        ON r.response_id = m.response_id
    WHERE sender_role = 'employer'
      AND sent_at BETWEEN created_at AND created_at + INTERVAL '7 days'
),
employer_calls AS (
    SELECT
        c.response_id,
        c.employer_id,
        call_id AS event_id,
        call_at AS event_at,
        'call' AS event_type
    FROM calls c
    JOIN responses r
        ON r.response_id = c.response_id
    WHERE caller_role = 'employer'
      AND call_at BETWEEN created_at AND created_at + INTERVAL '7 days'
),
events AS (
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM employer_messages
    UNION ALL
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM employer_calls
),
timeline AS (
    SELECT
        response_id,
        employer_id,
        event_id,
        event_at,
        event_type,
        ROW_NUMBER() OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS event_number,
        LAG(event_at) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS previous_event_at,
        LEAD(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS next_event_type,
        COUNT(*) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS events_so_far,
        FIRST_VALUE(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS first_event_type,
        LAST_VALUE(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS last_event_type
    FROM events
),
-- Запрос для проверки витрины уровня события:
/*SELECT
    response_id,
    employer_id,
    event_id,
    event_at,
    event_type,
    event_number,
    previous_event_at,
    next_event_type,
    event_at - previous_event_at AS time_from_previous,
    events_so_far,
    first_event_type,
    last_event_type
FROM timeline
ORDER BY response_id, event_number;*/

-- Витрина уровня отклика:
response_mart AS (
    SELECT
        r.response_id,
        v.employer_id,
        v.professional_role,
        r.status,
        COUNT(t.event_id) AS communication_count,
        COUNT(t.event_id) FILTER (WHERE t.event_type = 'call') AS calls_count,
        COUNT(t.event_id) FILTER (WHERE t.event_type = 'message') AS messages_count,
        MIN(t.event_at) AS first_event_at,
        MAX(t.event_type) FILTER (WHERE t.event_number = 1) AS first_event_type,
        MAX(t.event_type) FILTER (WHERE t.event_number = 2) AS second_event_type,
        MAX(t.last_event_type) AS last_event_type,
        EXTRACT(EPOCH FROM (MIN(t.event_at) - r.created_at)) / 3600 AS hours_to_first_communication, -- EXTRACT(EPOCH.. для перевода в секунды
        MAX(EXTRACT(EPOCH FROM (t.event_at - t.previous_event_at)) / 3600) AS max_gap_hours -- и удобного подсчёта времени между событиями
    FROM responses r
    JOIN vacancies v
        ON v.vacancy_id = r.vacancy_id
    LEFT JOIN timeline t
        ON t.response_id = r.response_id
    GROUP BY
        r.response_id,
        v.employer_id,
        v.professional_role,
        r.status,
        r.created_at
)
-- Запрос для проверки витрины уровня отклика:
/*SELECT
    response_id,
    employer_id,
    professional_role,
    status,
    communication_count,
    calls_count,
    messages_count,
    first_event_at,
    first_event_type,
    second_event_type,
    last_event_type,
    ROUND(hours_to_first_communication, 2) AS hours_to_first_communication,
    ROUND(max_gap_hours, 2) AS max_gap_hours
FROM response_mart
ORDER BY response_id;*/

-- Контрольные значения:
SELECT
    COUNT(*) AS responses_total,
    COUNT(*) FILTER (WHERE communication_count > 0) AS with_communication,
    COUNT(*) FILTER (WHERE communication_count = 0) AS without_communication,
    COUNT(*) FILTER (WHERE first_event_type = 'message') AS first_message,
    COUNT(*) FILTER (WHERE first_event_type = 'call') AS first_call
FROM response_mart;
-- Контрольные значения:
-- 1) Строк в витрине: 628
-- 2) Откликов с коммуникацией: 382
-- 3) Откликов без коммуникации: 246
-- 4) Первая коммуникация сообщение: 314
-- 5) Первая коммуникация звонок: 68


-- ЗАДАНИЕ 4. Рейтинг работодателей внутри направления
WITH employer_messages AS (
    SELECT
        m.response_id,
        m.employer_id,
        message_id AS event_id,
        sent_at AS event_at,
        'message' AS event_type
    FROM messages m
    JOIN responses r
        ON r.response_id = m.response_id
    WHERE sender_role = 'employer'
      AND sent_at BETWEEN created_at AND created_at + INTERVAL '7 days'
),
employer_calls AS (
    SELECT
        c.response_id,
        c.employer_id,
        call_id AS event_id,
        call_at AS event_at,
        'call' AS event_type
    FROM calls c
    JOIN responses r
        ON r.response_id = c.response_id
    WHERE caller_role = 'employer'
      AND call_at BETWEEN created_at AND created_at + INTERVAL '7 days'
),
events AS (
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM employer_messages
    UNION ALL
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM employer_calls
),
timeline AS (
    SELECT
        response_id,
        employer_id,
        event_id,
        event_at,
        event_type,
        ROW_NUMBER() OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS event_number,
        LAG(event_at) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS previous_event_at,
        LEAD(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS next_event_type,
        COUNT(*) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS events_so_far,
        FIRST_VALUE(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS first_event_type,
        LAST_VALUE(event_type) OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS last_event_type
    FROM events
),
-- Витрина из задания 3
response_mart AS (
    SELECT
        r.response_id,
        v.employer_id,
        v.professional_role,
        r.status,
        COUNT(t.event_id) AS communication_count,
        COUNT(t.event_id) FILTER (WHERE t.event_type = 'call') AS calls_count,
        COUNT(t.event_id) FILTER (WHERE t.event_type = 'message') AS messages_count,
        MIN(t.event_at) AS first_event_at,
        MAX(t.event_type) FILTER (WHERE t.event_number = 1) AS first_event_type,
        MAX(t.event_type) FILTER (WHERE t.event_number = 2) AS second_event_type,
        MAX(t.last_event_type) AS last_event_type,
        EXTRACT(EPOCH FROM (MIN(t.event_at) - r.created_at)) / 3600 AS hours_to_first_communication, -- EXTRACT(EPOCH.. для перевода в секунды
        MAX(EXTRACT(EPOCH FROM (t.event_at - t.previous_event_at)) / 3600) AS max_gap_hours -- и удобного подсчёта времени между событиями
    FROM responses r
    JOIN vacancies v
        ON v.vacancy_id = r.vacancy_id
    LEFT JOIN timeline t
        ON t.response_id = r.response_id
    GROUP BY
        r.response_id,
        v.employer_id,
        v.professional_role,
        r.status,
        r.created_at
),
employer_stats AS (
    SELECT
        professional_role,
        employer_id,
        COUNT(*) AS responses_count,
        COUNT(*) FILTER (WHERE communication_count > 0) AS processed_responses_count,
        100.0 * COUNT(*) FILTER
            (WHERE communication_count > 0) / NULLIF(COUNT(*), 0)
        AS processed_share_pct,
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY hours_to_first_communication
        ) AS median_first_contact_hours,
        PERCENTILE_CONT(0.9) WITHIN GROUP (
            ORDER BY hours_to_first_communication
        ) AS p90_first_contact_hours,
        100.0 * COUNT(*) FILTER (WHERE status = 'invited')
            / NULLIF(COUNT(*), 0) AS invited_conversion_pct
    FROM response_mart
    GROUP BY professional_role, employer_id
    HAVING COUNT(*) >= 8
),
ranked_employers AS (
    SELECT
        professional_role,
        employer_id,
        responses_count,
        processed_responses_count,
        processed_share_pct,
        median_first_contact_hours,
        p90_first_contact_hours,
        invited_conversion_pct,
        DENSE_RANK() OVER (
            PARTITION BY professional_role
            ORDER BY
                processed_share_pct DESC,
                median_first_contact_hours ASC NULLS LAST
        ) AS employer_rank
    FROM employer_stats
)
SELECT
    professional_role,
    employer_rank,
    employer_id,
    responses_count,
    processed_responses_count,
    ROUND(processed_share_pct, 2) AS processed_share_pct,
    ROUND(median_first_contact_hours::numeric, 2) AS median_first_contact_hours,
    ROUND(p90_first_contact_hours::numeric, 2) AS p90_first_contact_hours,
    ROUND(invited_conversion_pct, 2) AS invited_conversion_pct
FROM ranked_employers
WHERE employer_rank <= 2
ORDER BY professional_role, employer_rank, employer_id;
-- Результат:
-- Аналитик данных	1	109
-- Аналитик данных	2	103
-- Дата-инженер	1	106
-- Дата-инженер	2	101
-- Продуктовый аналитик	1	103
-- Продуктовый аналитик	2	102
-- Разработчик	1	112
-- Разработчик	2	104
-- Тестировщик	1	107
-- Тестировщик	2	108


-- ЗАДАНИЕ 5. Скорость ответа работодателя в переписке
WITH linked_messages_7d AS (
    SELECT
        m.response_id,
        m.employer_id,
        message_id,
        sent_at,
        sender_role
    FROM messages m
    JOIN responses r
        ON r.response_id = m.response_id
    JOIN vacancies v
        ON v.vacancy_id = r.vacancy_id
    WHERE sent_at BETWEEN created_at AND created_at + INTERVAL '7 days'
      AND m.vacancy_id = r.vacancy_id
      AND m.employer_id = v.employer_id
      AND m.applicant_id IS NOT DISTINCT FROM r.resume_id
),
message_timeline AS (
    SELECT
        response_id,
        employer_id,
        message_id,
        sent_at,
        sender_role,
        LAG(sender_role) OVER (
            PARTITION BY response_id
            ORDER BY sent_at, message_id
        ) AS previous_sender_role,
        LAG(sent_at) OVER (
            PARTITION BY response_id
            ORDER BY sent_at, message_id
        ) AS previous_message_at
    FROM linked_messages_7d
)
SELECT
    response_id,
    employer_id,
    message_id,
    sent_at,
    sender_role,
    previous_sender_role,
    previous_message_at
FROM message_timeline
ORDER BY response_id, sent_at, message_id;

-- Ответы работодателя, отправленные сразу после сообщения кандидата, и статистика:
WITH linked_messages_7d AS (
    SELECT
        m.response_id,
        m.employer_id,
        message_id,
        sent_at,
        sender_role
    FROM messages m
    JOIN responses r
        ON r.response_id = m.response_id
    JOIN vacancies v
        ON v.vacancy_id = r.vacancy_id
    WHERE sent_at BETWEEN created_at AND created_at + INTERVAL '7 days'
      AND m.vacancy_id = r.vacancy_id
      AND m.employer_id = v.employer_id
      AND m.applicant_id IS NOT DISTINCT FROM r.resume_id
),
message_timeline AS (
    SELECT
        response_id,
        employer_id,
        message_id,
        sent_at,
        sender_role,
        LAG(sender_role) OVER (
            PARTITION BY response_id
            ORDER BY sent_at, message_id
        ) AS previous_sender_role,
        LAG(sent_at) OVER (
            PARTITION BY response_id
            ORDER BY sent_at, message_id
        ) AS previous_message_at
    FROM linked_messages_7d
),
employer_replies AS (
    SELECT
        response_id,
        employer_id,
        message_id,
        EXTRACT(EPOCH FROM (sent_at - previous_message_at)) / 3600.0 AS response_hours
    FROM message_timeline
    WHERE sender_role = 'employer'
    AND previous_sender_role = 'applicant'
),
employer_stats AS (
    SELECT
        employer_id,
        COUNT(*) AS reply_cnt,
        AVG(response_hours) AS avg_response_hours,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY response_hours) AS median_response_hours,
        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY response_hours) AS p90_response_hours
    FROM employer_replies
    GROUP BY employer_id
)
SELECT
    employer_id,
    reply_cnt,
    ROUND(avg_response_hours::numeric, 2) AS avg_response_hours,
    ROUND(median_response_hours::numeric, 2) AS median_response_hours,
    ROUND(p90_response_hours::numeric, 2) AS p90_response_hours,
    SUM(reply_cnt) OVER () AS total_reply_cnt
FROM employer_stats
ORDER BY median_response_hours;
-- Контрольные значения:
-- 1) Общее количество найденных ответов: 749.
-- 2) Работодатель с минимальной медианой: 107.
-- 3) Его медиана времени ответа: 3.93 часа.


-- ЗАДАНИЕ 6. Сложные типы данных
-- 1. Теги звонков работодателя:
WITH employer_calls_7d AS (
    SELECT
        call_id,
        call_tags,
        (
            (c.status = 'successful'
             AND 'connected' = ANY(call_tags)
             AND NOT ('no_answer' = ANY(call_tags))
             AND NOT ('technical_error' = ANY(call_tags)))
            OR
            (c.status = 'unsuccessful'
             AND 'no_answer' = ANY(call_tags)
             AND NOT ('connected' = ANY(call_tags))
             AND NOT ('technical_error' = ANY(call_tags)))
            OR
            (c.status = 'error'
             AND 'technical_error' = ANY(call_tags)
             AND NOT ('connected' = ANY(call_tags))
             AND NOT ('no_answer' = ANY(call_tags)))
        ) AS tags_consistent
    FROM calls c
    JOIN responses r
        ON r.response_id = c.response_id
    WHERE caller_role = 'employer'
      AND call_at BETWEEN created_at AND created_at + INTERVAL '7 days'
)
SELECT
    COUNT(*) FILTER (WHERE tags_consistent AND 'screening' = ANY(call_tags)) AS screening_calls,
    COUNT(*) FILTER (WHERE tags_consistent AND 'interview' = ANY(call_tags)) AS interview_calls,
    COUNT(*) FILTER (WHERE tags_consistent AND 'follow_up' = ANY(call_tags)) AS follow_up_calls,
    COUNT(*) FILTER (WHERE tags_consistent AND 'details' = ANY(call_tags)) AS details_calls,
    COUNT(*) FILTER (
        WHERE tags_consistent
          AND ('screening' = ANY(call_tags)
               OR 'interview' = ANY(call_tags)
               OR 'follow_up' = ANY(call_tags)
               OR 'details' = ANY(call_tags))
    ) AS valid_calls_with_business_tag,
    ROUND(AVG(CARDINALITY(call_tags)) FILTER (WHERE tags_consistent), 2) AS avg_tags_per_valid_call
FROM employer_calls_7d;
-- Вывод:
-- 1) screening - 25.
-- 2) interview - 31.
-- 3) follow_up - 29.
-- 4) details - 23.
-- 5) Количество валидных звонков, содержащих хотя бы один
-- из перечисленных бизнес-тегов - 108.
-- 6) Среднее количество тегов на один валидный звонок - 4.


-- 2. Метаданные сообщений:
WITH employer_messages_7d AS (
    SELECT
        message_id,
        COALESCE(message_meta ->> 'channel', '(канал отсутствует)') AS channel,
        (message_meta ->> 'is_read')::boolean AS is_read,
        jsonb_array_length(message_meta -> 'attachments') AS attachments_count
    FROM messages m
    JOIN responses r
        ON r.response_id = m.response_id
    WHERE sender_role = 'employer'
      AND sent_at BETWEEN created_at AND created_at + INTERVAL '7 days'
)
SELECT
    channel,
    COUNT(*) AS messages_count,
    COUNT(is_read) AS messages_with_read_flag,
    COUNT(*) FILTER (WHERE is_read = FALSE) AS unread_messages,
    ROUND(
        100.0 * COUNT(*) FILTER 
        (WHERE is_read = FALSE) / NULLIF(COUNT(is_read), 0),2)
        AS unread_known_read_st_pct,
    COUNT(*) FILTER
    (WHERE attachments_count > 0)
    AS messages_with_attachments,
    ROUND(100.0 * COUNT(*) FILTER (WHERE attachments_count > 0) / COUNT(*),2)
    AS messages_with_attachments_pct
FROM employer_messages_7d
GROUP BY channel
ORDER BY channel;
-- Вывод: два канала, mobile_app и web.
-- 1) mobile_app: сообщений 360, с признаком прочтения 360, непрочитанных 36,
-- доля непрочитанных 10.00%, с вложением 14, доля с вложением 3.89%.
-- 2) web: сообщений 628, с признаком прочтения 628, непрочитанных 52,
-- доля непрочитанных 8.28%, с вложением 25, доля с вложением 3.98%.
-- Признак прочтения есть у всех сообщений (88 непрочитанных). Сообщений без канала нет.


-- ЗАДАНИЕ 7. Что связано с приглашением?
-- Гипотезы:
-- 1. Работодатель быстрее выходит на связь по откликам, которые
-- заканчиваются приглашением. Среди откликов, получивших приглашение,
-- выше доля откликов с первым контактом работодателя в первые 24 часа
-- и меньше медиана времени до первого контакта.
-- 2. В откликах с приглашением кандидат чаще начинает
-- коммуникацию и чаще идёт двусторонняя переписка.
--
-- Для проверки гипотез необходимо посмотреть на следующие характеристики коммуникации:
-- 1) Доля откликов с первым контактом работодателя в первые 24 часа, медиана часов
-- до первого контакта.
-- 2) Доля откликов, где первой коммуникацией была коммуникация кандидата.
-- 3) Доля откликов с двусторонней перепиской.
-- А также их зависимость от числа приглашений.

-- Проверка гипотезы 1:
WITH employer_messages AS (
    SELECT
        m.response_id,
        m.employer_id,
        message_id AS event_id,
        m.sent_at AS event_at,
        'message' AS event_type
    FROM messages m
    JOIN responses r
        ON r.response_id = m.response_id
    WHERE sender_role = 'employer'
      AND sent_at BETWEEN created_at AND created_at + INTERVAL '7 days'
),
employer_calls AS (
    SELECT
        c.response_id,
        c.employer_id,
        call_id AS event_id,
        call_at AS event_at,
        'call' AS event_type
    FROM calls c
    JOIN responses r
        ON r.response_id = c.response_id
    WHERE caller_role = 'employer'
      AND call_at BETWEEN created_at AND created_at + INTERVAL '7 days'
),
events AS (
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM employer_messages
    UNION ALL
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM employer_calls
),
event_stats AS (
    SELECT
        response_id,
        MIN(event_at) AS first_employer_contact_at
    FROM events
    GROUP BY response_id
),
response_metrics AS (
    SELECT
        r.response_id,
        r.status,
        CASE WHEN r.status = 'invited' THEN 'invited' ELSE 'other_status' END AS outcome_group,
        EXTRACT(EPOCH FROM (es.first_employer_contact_at - r.created_at)) / 3600 AS hours_to_first_contact,
        CASE WHEN es.response_id IS NOT NULL THEN 1 ELSE 0 END AS has_contact,
        CASE
            WHEN es.first_employer_contact_at <= r.created_at + INTERVAL '24 hours' THEN 1
            ELSE 0
        END AS contact_within_24h
    FROM responses r
    LEFT JOIN event_stats es
        ON es.response_id = r.response_id
)
SELECT
    'invited и остальные' AS breakdown,
    outcome_group AS group_name,
    COUNT(*) AS responses_count,
    SUM(has_contact) AS responses_with_contact,
    ROUND(100.0 * AVG(has_contact), 2) AS contact_pct,
    SUM(contact_within_24h) AS responses_contact_24h,
    ROUND(100.0 * AVG(contact_within_24h), 2) AS contact_24h_pct,
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_to_first_contact)::numeric,
        2
    ) AS median_hours_to_first_contact
FROM response_metrics
GROUP BY outcome_group
 
UNION ALL
 
SELECT
    'по статусам отклика' AS breakdown,
    status AS group_name,
    COUNT(*) AS responses_count,
    SUM(has_contact) AS responses_with_contact,
    ROUND(100.0 * AVG(has_contact), 2) AS contact_pct,
    SUM(contact_within_24h) AS responses_contact_24h,
    ROUND(100.0 * AVG(contact_within_24h), 2) AS contact_24h_pct,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP
    	(ORDER BY hours_to_first_contact)::numeric, 2)
        AS median_hours_to_first_contact
FROM response_metrics
GROUP BY status
ORDER BY breakdown, group_name;
-- Результат:

-- группа откликов, с контактом работодателя, контакт за 24 ч, шт. и %, медиана часов до первого контакта:
-- invited и остальные - invited - 92 - 54 - 58.70 - 18 - 19.57 - 51.08
-- invited и остальные - other_status - 536 - 328 - 61.19 - 104	19.40 - 54.67
-- по статусам отклика -  invited - 92 - 54 - 58.70 - 18 - 19.57 - 51.08
-- по статусам отклика - new - 94 - 58 - 61.70 - 19 - 20.21 - 32.68
-- по статусам отклика - rejected - 260 - 157 - 60.38 - 53 - 20.38 - 54.33
-- по статусам отклика	viewed - 182 - 113 - 62.09 - 32 - 17.58 - 57.17


-- Таким образом, гипотеза 1 не подтверждается. Доля контактов в первые 24 часа составила 19.57% (18 из 92)
-- у получивших приглашение против 19.40% (104 из 536) у остальных.
-- Медиана времени до первого контакта у приглашённых чуть меньше (51.08 против 54.67 часа),
-- но эта разница в 3.6 часа меньше, чем разброс медиан внутри группы остальных (от 32.67 у new
-- до 57.17 у viewed). При 92 откликах invited различия менее 9 п.п. выявить нельзя.
-- Доля откликов с любым контактом работодателя тоже почти одинакова (58.70% против 61.19%).
-- Возможно гипотезу удалось бы лучше проверить на большем количестве информации.
 
-- Проверка гипотезы 2:
WITH all_events AS (
    SELECT
        m.response_id,
        message_id AS event_id,
        sent_at AS event_at,
        'message' AS event_type,
        sender_role AS actor_role
    FROM messages m
    JOIN responses r
        ON r.response_id = m.response_id
    WHERE sent_at BETWEEN created_at AND created_at + INTERVAL '7 days'
 
    UNION ALL
 
    SELECT
        c.response_id,
        call_id AS event_id,
        call_at AS event_at,
        'call' AS event_type,
        caller_role AS actor_role
    FROM calls c
    JOIN responses r
        ON r.response_id = c.response_id
    WHERE call_at BETWEEN created_at AND created_at + INTERVAL '7 days'
),
ranked_events AS (
    SELECT
        response_id,
        actor_role,
        ROW_NUMBER() OVER (
            PARTITION BY response_id
            ORDER BY event_at, event_type, event_id
        ) AS event_number
    FROM all_events
),
first_events AS (
    SELECT
        response_id,
        actor_role
    FROM ranked_events
    WHERE event_number = 1
),
message_directions AS (
    SELECT
        response_id,
        COUNT(*) FILTER (WHERE actor_role = 'employer') AS employer_messages_count,
        COUNT(*) FILTER (WHERE actor_role = 'applicant') AS applicant_messages_count
    FROM all_events
    WHERE event_type = 'message'
    GROUP BY response_id
),
response_metrics AS (
    SELECT
        r.response_id,
        r.status,
        CASE WHEN r.status = 'invited' THEN 'invited' ELSE 'other_status' END AS outcome_group,
        CASE WHEN fe.response_id IS NOT NULL THEN 1 ELSE 0 END AS has_communication,
        CASE
            WHEN fe.actor_role = 'applicant' THEN 1
            WHEN fe.actor_role = 'employer' THEN 0
        END AS applicant_started,
        CASE
            WHEN md.employer_messages_count > 0
             AND md.applicant_messages_count > 0 THEN 1
            ELSE 0
        END AS two_way_messaging
    FROM responses r
    LEFT JOIN first_events fe
        ON fe.response_id = r.response_id
    LEFT JOIN message_directions md
        ON md.response_id = r.response_id
)
SELECT
    'invited и остальные' AS breakdown,
    outcome_group AS group_name,
    COUNT(*) AS responses_count,
    SUM(has_communication) AS responses_with_communication,
    SUM(applicant_started) AS applicant_started_count,
    ROUND(100.0 * AVG(applicant_started), 2) AS applicant_started_pct,
    SUM(two_way_messaging) AS two_way_count,
    ROUND(
        100.0 * SUM(two_way_messaging) / NULLIF(SUM(has_communication), 0),
        2
    ) AS two_way_pct_of_communicated,
    ROUND(100.0 * AVG(two_way_messaging), 2) AS two_way_pct_of_all
FROM response_metrics
GROUP BY outcome_group
 
UNION ALL
 
SELECT
    'по статусам отклика' AS breakdown,
    status AS group_name,
    COUNT(*) AS responses_count,
    SUM(has_communication) AS responses_with_communication,
    SUM(applicant_started) AS applicant_started_count,
    ROUND(100.0 * AVG(applicant_started), 2) AS applicant_started_pct,
    SUM(two_way_messaging) AS two_way_count,
    ROUND(100.0 * SUM(two_way_messaging)
    / NULLIF(SUM(has_communication), 0),2)
    AS two_way_pct_of_communicated,
    ROUND(100.0 * AVG(two_way_messaging), 2) AS two_way_pct_of_all
FROM response_metrics
GROUP BY status
ORDER BY breakdown, group_name;
-- Результат:

-- группа, всего откликов, с коммуникацией любой стороны, первым был кандидат (шт. и %),
-- двусторонняя переписка (шт.), % среди откликов с коммуникацией, % среди всех откликов:

-- invited и остальные - invited - 92 - 56 - 15 - 26.79 - 47 - 83.93 - 51.09
-- invited и остальные - other_status - 536 - 342 - 111 - 32.46 - 297 - 86.84 - 55.41
-- по статусам отклика - invited - 92 - 56 - 15	26.79 - 47 - 83.93 - 51.09
-- по статусам отклика - new - 94 - 63 - 16 - 25.40	51 - 80.95 - 54.26
-- по статусам отклика - rejected - 260 - 164 - 63 - 38.41 - 145 - 88.41 - 55.77
-- по статусам отклика - viewed - 182 - 115	32 - 27.83 - 101 - 87.83 - 55.49
--
-- Таким образом, гипотеза 2 так же не подтверждается. Обе её части не выполняются:
-- 1) Кандидат начал коммуникацию в 26.79% откликов с приглашением (то есть 15 из 56).
-- против 32.46% у остальных (111 из 342), то есть у откликов со статусом invited даже реже.
-- 2) Двусторонняя переписка есть в 83.93% откликов invited с коммуникацией
-- (47 из 56) против 86.84% у остальных (297 из 342): ниже на 2.9 п.п.
-- По всем откликам картина та же (51.09% против 55.41%).

-- Самая высокая доля инициативы кандидата - у отклонённых откликов (38.41%, 63 из 164): если
-- связь с исходом и есть, то скорее с отказом, а не с приглашением, но и эта разница незначительна.
-- Также следует отметить, что здесь присутствуют некоторые ограничения.
-- У invited всего 56 откликов с коммуникацией, поэтому различия менее 10-13 п.п.
-- по этим показателям выявить нельзя. статус отклика представляет собой один срез на момент выгрузки, и
-- неизвестно, было приглашение до коммуникации или после, поэтому причинность не оценивается.
--
-- Общий вывод по заданию: ни одна из двух гипотез не подтвердилась. По измеренным признакам
-- отклики с приглашением не отличаются от остальных.


-- ЗАДАНИЕ 8. Итог исследования
-- Итог исследования:
-- 1) После получения откликов работодатели выходят на связь не всегда. Из 628 откликов
-- коммуникация работодателя в первые 7 суток была по 382, а по 246 откликам не было
-- ни звонка, ни сообщения (задание 3).
-- 2) Коммуникация чаще начинается с переписки, чем со звонка. Сообщением открываются 314 откликов, звонком
-- 68 (задание 3), а каждый из 108 звонков работодателя несёт ровно один бизнес-тег
-- (interview 31, follow_up 29, screening 25, details 23; задание 6).
-- 3) Первый контакт приходит не сразу и требует времени. Медиана времени до первого ответа
-- составляет 51-55 часов (задание 7), зато в уже начатой переписке работодатели
-- отвечают кандидатам заметно быстрее. Медианы ответов работодателей лежат
-- в диапазоне 3.9-4.9 часа (задание 5).
-- 4) Работодатели различаются прежде всего охватом, а не скоростью ответа. Среди лидеров своих
-- направлений доля обработанных откликов колеблется от 45.8% (работодатель 101,
-- дата-инженеры) до 89.5% (работодатель 109, аналитики данных) (задание 4), тогда как
-- медианы времени ответа в переписке различаются лишь на час.

-- 5) В качестве дополнительного рассчёта могу предложить рассмотреть статистику внутри направлений:
WITH employer_messages AS (
    SELECT
        m.response_id,
        m.employer_id,
        message_id AS event_id,
        sent_at AS event_at,
        'message' AS event_type
    FROM messages m
    JOIN responses r
        ON r.response_id = m.response_id
    WHERE sender_role = 'employer'
      AND sent_at BETWEEN created_at AND created_at + INTERVAL '7 days'
),
employer_calls AS (
    SELECT
        c.response_id,
        c.employer_id,
        call_id AS event_id,
        call_at AS event_at,
        'call' AS event_type
    FROM calls c
    JOIN responses r
        ON r.response_id = c.response_id
    WHERE caller_role = 'employer'
      AND call_at BETWEEN created_at AND created_at + INTERVAL '7 days'
),
events AS (
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM employer_messages
    UNION ALL
    SELECT response_id, employer_id, event_id, event_at, event_type
    FROM employer_calls
),
response_mart AS (
    SELECT
        r.response_id,
        v.employer_id,
        v.professional_role,
        r.status,
        COUNT(e.event_id) AS communication_count,
        EXTRACT(EPOCH FROM (MIN(e.event_at) - r.created_at)) / 3600 AS hours_to_first_communication
    FROM responses r
    JOIN vacancies v
        ON v.vacancy_id = r.vacancy_id
    LEFT JOIN events e
        ON e.response_id = r.response_id
    GROUP BY
        r.response_id,
        v.employer_id,
        v.professional_role,
        r.status,
        r.created_at
)
SELECT
    professional_role,
    COUNT(*) AS responses_count,
    COUNT(*) FILTER (WHERE communication_count > 0) AS processed_responses_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE communication_count > 0)
    / NULLIF(COUNT(*), 0), 2)
    AS processed_share_pct,
    COUNT(*) FILTER (WHERE status = 'invited') AS invited_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'invited')
    / NULLIF(COUNT(*), 0), 2)
    AS invited_conversion_pct
FROM response_mart
GROUP BY rm.professional_role
ORDER BY invited_conversion_pct DESC;
-- Результат:
-- направление, кол-во откликов, обработано, доля %, приглашений, конверсия %):
-- Тестировщик - 39 - 29 - 74.36 - 14 - 35.90
-- Разработчик - 139 - 82 - 58.99 - 24 - 17.27
-- Аналитик данных - 313 - 190 - 60.70 - 38 - 12.14
-- Дата-инженер - 34 - 18 - 52.94 - 4 - 11.76
-- Продуктовый аналитик - 103 - 63 - 61.17 - 12 - 11.65

-- Направления отличаются прежде всего конверсией в приглашение. У тестировщиков она
-- 35.9% (14 из 39 откликов) против 17.3% у разработчиков и 11.7-12.1% у аналитиков и
-- дата-инженеров, при этом доля обработанных откликов по направлениям лежит в диапазоне
-- от 52.9% до 74.4%.

-- 6) Отклики с приглашением по измеренным признакам коммуникации не отличаются от остальных.
-- Контакт в первые 24 часа получили 19.57% приглашений против 19.40% остальных, на отклик
-- пришлось 1.63 против 1.76 коммуникации работодателя, двусторонняя переписка есть у 51.09%
-- против 55.41%, поэтому обе гипотезы задания 7 не подтвердились.
-- 7) Статус отклика является одним срезом, и неизвестно, появилось ли приглашение до коммуникации или после.

-- Ограничения анализа: окно 7 суток, небольшая группа invited (92 отклика), у многих пар
-- работодатель-направление меньше 30 откликов, 8 звонков без response_id исключены,
-- а различия между направлениями могут смешиваться с различиями вакансий и работодателей.
-- Следующий вопрос: как связаны момент смены статуса отклика и время коммуникации?
-- Для ответа нужны история смен статусов, содержание коммуникаций и сравнение работодателей
-- внутри одной вакансии.
