-- ============================================================
-- EnterpriseAdmin 企业级后台管理系统 - 数据库验证脚本
-- 数据库：MySQL 8.0
-- 说明：用于接口/功能测试后的数据库数据一致性验证、慢查询分析、数据清理
-- 使用：每段 SQL 前的中文注释说明验证目的，按需在测试后执行
-- ============================================================

-- 切换到测试库（实际库名以部署为准）
USE enterprise_admin_test;


-- ============================================================
-- 一、用户 CRUD 后数据一致性验证
-- ============================================================

-- 1.1 验证用户新增：查询 sys_user 记录数与新增用户是否存在
-- 验证目的：新增用户接口/功能执行后，确认用户表落库且字段正确
SELECT COUNT(*) AS user_total FROM sys_user WHERE del_flag = '0';

-- 1.2 验证新增用户字段完整性（以测试用户 lisi 为例）
-- 验证目的：确认用户名、昵称、手机号、邮箱、部门、状态、创建时间等字段正确写入
SELECT user_id, user_name, nick_name, phonenumber, email, dept_id, status, create_time
FROM sys_user
WHERE user_name = 'lisi' AND del_flag = '0';

-- 1.3 验证用户名唯一性约束（期望仅 1 条有效记录）
-- 验证目的：防止重复新增导致脏数据
SELECT user_name, COUNT(*) AS cnt
FROM sys_user
WHERE del_flag = '0'
GROUP BY user_name
HAVING cnt > 1;

-- 1.4 验证用户修改：昵称修改后字段是否更新
-- 验证目的：确认 PUT /system/user 修改操作正确落库
SELECT user_id, nick_name, update_time, update_by
FROM sys_user
WHERE user_id = 2;

-- 1.5 验证用户状态变更：禁用用户后 status 字段
-- 验证目的：确认 changeStatus 接口更新了 status 字段（0=启用 1=禁用）
SELECT user_id, user_name, status
FROM sys_user
WHERE user_id = 2;

-- 1.6 验证密码重置：password 字段是否更新为默认加密值
-- 验证目的：确认 resetPwd 接口更新了密码哈希
SELECT user_id, user_name, password, update_time
FROM sys_user
WHERE user_id = 2;

-- 1.7 验证用户删除：逻辑删除时 del_flag 置 1，物理删除时记录消失
-- 验证目的：确认删除接口按设计执行逻辑/物理删除
SELECT user_id, user_name, del_flag
FROM sys_user
WHERE user_id = 2;


-- ============================================================
-- 二、用户-角色-岗位关联表验证
-- ============================================================

-- 2.1 验证用户角色关联：用户新增时分配的角色是否写入 sys_user_role
-- 验证目的：确认用户-角色关联表记录正确
SELECT ur.user_id, u.user_name, ur.role_id, r.role_name
FROM sys_user_role ur
JOIN sys_user u ON ur.user_id = u.user_id
JOIN sys_role r ON ur.role_id = r.role_id
WHERE ur.user_id = 2;

-- 2.2 验证用户岗位关联：sys_user_post 关联记录
SELECT up.user_id, u.user_name, up.post_id, p.post_name
FROM sys_user_post up
JOIN sys_user u ON up.user_id = u.user_id
JOIN sys_post p ON up.post_id = p.post_id
WHERE up.user_id = 2;

-- 2.3 验证删除用户后关联表级联清理
-- 验证目的：删除用户后 sys_user_role / sys_user_post 对应记录应同步清除
SELECT COUNT(*) AS remain_role_link FROM sys_user_role WHERE user_id = 2;
SELECT COUNT(*) AS remain_post_link FROM sys_user_post WHERE user_id = 2;


-- ============================================================
-- 三、角色权限分配后验证 role_menu 关联表
-- ============================================================

-- 3.1 验证角色菜单分配：sys_role_menu 关联记录与勾选菜单一致
-- 验证目的：角色分配菜单权限后，关联表应新增对应记录
SELECT rm.role_id, r.role_name, rm.menu_id, m.menu_name
FROM sys_role_menu rm
JOIN sys_role r ON rm.role_id = r.role_id
JOIN sys_menu m ON rm.menu_id = m.menu_id
WHERE rm.role_id = 3
ORDER BY m.order_num;

-- 3.2 验证取消菜单权限：关联表对应记录删除
-- 验证目的：取消勾选菜单后，sys_role_menu 对应记录应被删除
SELECT menu_id
FROM sys_role_menu
WHERE role_id = 3 AND menu_id = 100;

-- 3.3 统计角色已分配菜单数量
SELECT role_id, COUNT(*) AS menu_count
FROM sys_role_menu
GROUP BY role_id;

-- 3.4 验证角色数据权限：sys_role_dept 关联记录（自定义数据权限）
SELECT rd.role_id, r.role_name, rd.dept_id, d.dept_name
FROM sys_role_dept rd
JOIN sys_role r ON rd.role_id = r.role_id
JOIN sys_dept d ON rd.dept_id = d.dept_id
WHERE rd.role_id = 3;


-- ============================================================
-- 四、定时任务执行后验证任务执行日志与业务数据更新
-- ============================================================

-- 4.1 验证任务新增：sys_job 记录
SELECT job_id, job_name, job_group, invoke_target, cron_expression, status
FROM sys_job
WHERE job_name = '接口测试任务';

-- 4.2 验证任务执行日志：sys_job_log 新增记录
-- 验证目的：手动执行/定时触发后，日志表应新增执行记录
SELECT job_log_id, job_name, job_group, invoke_target, job_message, status, create_time
FROM sys_job_log
WHERE job_name = '接口测试任务'
ORDER BY create_time DESC
LIMIT 10;

-- 4.3 统计任务执行成功/失败次数
-- 验证目的：评估任务执行稳定性
SELECT status, COUNT(*) AS cnt
FROM sys_job_log
WHERE job_name = '接口测试任务'
GROUP BY status;

-- 4.4 验证任务暂停后不再产生新日志（对比执行前后日志数）
SELECT COUNT(*) AS log_count_after_pause
FROM sys_job_log
WHERE job_name = '接口测试任务' AND create_time > '2026-08-01 00:00:00';

-- 4.5 验证任务执行后业务数据更新（以任务调用 testTask 更新某统计表为例）
-- 验证目的：确认定时任务实际执行了业务逻辑并更新数据
SELECT job_name, job_message, create_time
FROM sys_job_log
WHERE status = '0' AND job_name = '接口测试任务'
ORDER BY create_time DESC LIMIT 1;


-- ============================================================
-- 五、文件上传后验证文件记录表
-- ============================================================

-- 5.1 验证文件上传记录：sys_file 新增记录
-- 验证目的：上传成功后文件记录表应写入文件名、路径、大小、类型、上传人
SELECT file_id, file_name, file_path, file_size, file_type, create_by, create_time
FROM sys_file
ORDER BY create_time DESC
LIMIT 10;

-- 5.2 验证文件大小限制：上传文件大小不超过配置上限（如 10MB）
-- 验证目的：确认大文件被拦截，落库记录均在上限内
SELECT file_id, file_name, file_size
FROM sys_file
WHERE file_size > 10485760;  -- 10MB = 10*1024*1024

-- 5.3 验证文件类型校验：仅允许类型落库
-- 验证目的：确认非法类型文件未落库
SELECT file_id, file_name, file_type
FROM sys_file
WHERE file_type NOT IN ('jpg', 'jpeg', 'png', 'gif', 'pdf', 'doc', 'docx', 'xls', 'xlsx');

-- 5.4 验证删除文件记录：记录清除且存储文件同步删除
SELECT COUNT(*) AS remain_file FROM sys_file WHERE file_id = 100;


-- ============================================================
-- 六、慢查询分析（配合 Druid 监控面板）
-- ============================================================

-- 6.1 开启慢查询日志（如未开启，需在 my.cnf 配置 slow_query_log=ON，long_query_time=1）
-- SHOW VARIABLES LIKE 'slow_query_log%';
-- SHOW VARIABLES LIKE 'long_query_time';

-- 6.2 查询当前活跃连接与执行中的 SQL（用于定位阻塞）
SELECT id, user, host, db, command, time, state, LEFT(info, 100) AS sql_text
FROM information_schema.processlist
WHERE command != 'Sleep'
ORDER BY time DESC;

-- 6.3 分析用户列表查询执行计划（验证索引使用情况）
-- 验证目的：确认分页查询走索引，避免全表扫描
EXPLAIN
SELECT * FROM sys_user WHERE del_flag = '0' ORDER BY user_id LIMIT 10;

-- 6.4 统计高频慢 SQL（Druid 监控中可直观查看，此处为 SQL 维度参考）
-- 验证目的：识别需要优化的高频/低效 SQL
SELECT schema_name, digest_text, count_star, sum_timer_wait/1000000000 AS sum_ms, avg_timer_wait/1000000 AS avg_ms
FROM performance_schema.events_statements_summary_by_digest
WHERE schema_name = 'enterprise_admin_test'
ORDER BY sum_timer_wait DESC
LIMIT 10;

-- 6.5 检查缺失索引的高代价查询表（用户名查询应命中索引）
EXPLAIN SELECT * FROM sys_user WHERE user_name = 'admin' AND del_flag = '0';


-- ============================================================
-- 七、操作日志与登录日志验证
-- ============================================================

-- 7.1 验证操作日志记录：接口操作后 sys_oper_log 写入审计记录
SELECT oper_id, title, business_type, method, oper_name, oper_time, cost_time
FROM sys_oper_log
ORDER BY oper_time DESC
LIMIT 10;

-- 7.2 验证登录日志：登录成功/失败记录
SELECT info_id, login_name, ipaddr, login_location, browser, os, status, msg, login_time
FROM sys_logininfor
ORDER BY login_time DESC
LIMIT 10;

-- 7.3 统计登录失败次数（配合限流验证）
SELECT login_name, COUNT(*) AS fail_count
FROM sys_logininfor
WHERE status = '1'
GROUP BY login_name
HAVING fail_count >= 5;


-- ============================================================
-- 八、数据清理脚本（测试后恢复数据）
-- 警告：以下脚本会清理测试产生的数据，请在测试环境执行，切勿在生产库运行
-- 建议执行前先备份： mysqldump -u root -p enterprise_admin_test > backup.sql
-- ============================================================

-- 开启事务，便于回滚
START TRANSACTION;

-- 8.1 清理测试新增的用户及其关联（保留预置数据，按规则清理测试用户名前缀）
DELETE FROM sys_user_role WHERE user_id IN (SELECT user_id FROM (SELECT user_id FROM sys_user WHERE user_name IN ('lisi','wangwu','zhangsan')) t);
DELETE FROM sys_user_post WHERE user_id IN (SELECT user_id FROM (SELECT user_id FROM sys_user WHERE user_name IN ('lisi','wangwu','zhangsan')) t);
DELETE FROM sys_user WHERE user_name IN ('lisi','wangwu','zhangsan');

-- 8.2 清理测试新增角色及关联
DELETE FROM sys_role_menu WHERE role_id IN (SELECT role_id FROM (SELECT role_id FROM sys_role WHERE role_key = 'test_role') t);
DELETE FROM sys_role_dept WHERE role_id IN (SELECT role_id FROM (SELECT role_id FROM sys_role WHERE role_key = 'test_role') t);
DELETE FROM sys_role WHERE role_key = 'test_role';

-- 8.3 清理测试定时任务及日志
DELETE FROM sys_job_log WHERE job_name = '接口测试任务';
DELETE FROM sys_job WHERE job_name = '接口测试任务';

-- 8.4 清理测试上传文件记录
DELETE FROM sys_file WHERE create_by = 'admin' AND create_time > '2026-08-01 00:00:00';

-- 8.5 清理测试操作日志与登录日志（可选，保留审计可注释）
-- DELETE FROM sys_oper_log WHERE create_time > '2026-08-01 00:00:00';
-- DELETE FROM sys_logininfor WHERE login_time > '2026-08-01 00:00:00';

-- 确认无误后提交；如有问题执行 ROLLBACK;
COMMIT;
-- ROLLBACK;

-- 8.6 验证清理结果（期望测试数据已清除）
SELECT COUNT(*) AS test_user_left FROM sys_user WHERE user_name IN ('lisi','wangwu','zhangsan');
SELECT COUNT(*) AS test_role_left FROM sys_role WHERE role_key = 'test_role';
SELECT COUNT(*) AS test_job_left FROM sys_job WHERE job_name = '接口测试任务';


-- ============================================================
-- 九、数据完整性自检（外键/关联一致性）
-- ============================================================

-- 9.1 检查存在用户-角色关联但角色已删除的脏数据
SELECT ur.* FROM sys_user_role ur
LEFT JOIN sys_role r ON ur.role_id = r.role_id
WHERE r.role_id IS NULL;

-- 9.2 检查存在角色-菜单关联但菜单已删除的脏数据
SELECT rm.* FROM sys_role_menu rm
LEFT JOIN sys_menu m ON rm.menu_id = m.menu_id
WHERE m.menu_id IS NULL;

-- 9.3 检查部门树层级自引用异常（parent_id 指向自己）
SELECT dept_id, dept_name, parent_id FROM sys_dept WHERE dept_id = parent_id;
