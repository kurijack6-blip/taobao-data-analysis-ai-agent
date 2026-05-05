CREATE TABLE user_behavior (
    user_id INT,
    item_id INT,
    category_id INT,
    behavior_type VARCHAR(10),
    timestamp BIGINT
);
create table user_rand as
    select *  from user_behavior
where rand()<0.1
limit 5000000;
select count(*) from user_rand;
delete from user_rand where timestamp<=0;#时间戳不可能e
delete  from user_rand where user_id is null or user_rand.user_id=0;#userid不可能为空或为0
#我现在要清除重复的值
with row_data as(
    select *,
        row_number() over (partition by user_rand.user_id,user_rand.item_id,user_rand.behavior_type,user_rand.timestamp)as rn
from user_rand
)
delete u from user_rand u join row_data r
on u.user_id=r.user_id
and u.item_id=r.item_id
and u.behavior_type=r.behavior_type
and u.timestamp=r.timestamp
where rn>1;#执行到这里
delete from user_rand where user_rand.behavior_type not in ('pv', 'fav', 'cart', 'buy');
#加索引
select count(*) from user_rand
where behavior_type='buy';
select count(*) from user_rand where (user_id,item_id,timestamp) in(
    select user_id,item_id,timestamp from
        (select user_id,behavior_type,item_id,timestamp,row_number() over (partition by user_id,item_id order by timestamp) as rn
         from user_rand) as emp1
    where rn=1 and emp1.behavior_type='buy'
);
-- 看看总共的 (user_id, item_id) 对里，有多少对是“只有一次行为且为buy”的
WITH pair_stats AS (
    SELECT user_id, item_id,
           COUNT(*) AS total_actions,
           SUM(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS buy_cnt
    FROM user_rand
    GROUP BY user_id, item_id
)
SELECT
    COUNT(*) AS total_pairs,                           -- 总 (user, item) 对
    SUM(CASE WHEN total_actions = 1 AND buy_cnt = 1
             THEN 1 ELSE 0 END) AS single_buy_pairs,  -- 只有一次行为且为buy的对
    SUM(CASE WHEN total_actions > 1 AND buy_cnt >= 1
             THEN 1 ELSE 0 END) AS multi_action_buy_pairs  -- 有多次交互且包含购买的
FROM pair_stats;
with hourly_user_cnt as(
    select user_rand.user_id,date_format(from_unixtime(timestamp),'%Y-%m-%d %H:00:00')as hour_dt,
           count(user_id) as usr_cnt
        from user_rand
    group by user_rand.user_id,date_format(from_unixtime(timestamp),'%Y-%m-%d %H:00:00')
),
hourly_global_bound as (
select  hour_dt,max(case when emp11.per_rank<=0.9999 then usr_cnt end)as cnt999
    from (select hour_dt ,usr_cnt, percent_rank() over (partition by hour_dt order by usr_cnt) as per_rank
    from hourly_user_cnt) as  emp11
   group by hour_dt
)
select
    hourly_user_cnt.user_id as '异常用户id',
    hourly_user_cnt.hour_dt as '异常发生时间',
    hourly_user_cnt.usr_cnt as '异常发生次数',
    hourly_global_bound.cnt999 AS '全局99.99%用户的上限值',
    ROUND(hourly_user_cnt.usr_cnt / hourly_global_bound.cnt999, 2) AS '超出正常上限的倍数'

    from hourly_user_cnt
join hourly_global_bound on hourly_user_cnt.hour_dt=hourly_global_bound.hour_dt
where  hourly_user_cnt.usr_cnt>hourly_global_bound.cnt999
and hourly_user_cnt.usr_cnt>1000;

alter table user_rand add index idx_uidtidtypestam(user_id,item_id,behavior_type,timestamp);
alter table user_rand add index idx_stamp(timestamp);
#这里只是查一下还有没有重复的
select user_rand.user_id,user_rand.item_id,user_rand.behavior_type,user_rand.timestamp,count(*)as cnt
from user_rand
group by
    user_rand.user_id,item_id,behavior_type,timestamp
having cnt>1;

-- 2. 新增自动计算列+索引,,耗时很长
ALTER TABLE user_rand
ADD COLUMN date DATE GENERATED ALWAYS AS (FROM_UNIXTIME(timestamp, '%Y-%m-%d')) STORED,
ADD COLUMN hour INT GENERATED ALWAYS AS (FROM_UNIXTIME(timestamp, '%H')) STORED,
ADD INDEX idx_date_hour (date, hour);
#某类目特别少订单，没啥意义了就删掉吧
delete from user_rand
where category_id in (select category_id from(select category_id
from user_rand
group by category_id
having count(*)<3)as emp);

#删除逾越部分，也就是定好时间的不能超出这9天，不然会影响后续分析
create table user_clean as
    select user_id,item_id,category_id,behavior_type,timestamp,date,hour
from user_rand
where user_id is not null
and item_id is not null
and category_id is not null
and behavior_type in ('pv','cart','fav','buy')
and date between '2017-11-25'and'2017-12-03';

select count(*) from user_clean;

select  count(*) from user_rand;
