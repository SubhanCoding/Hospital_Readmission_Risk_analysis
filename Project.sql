create database hospital_readmission;
use hospital_readmission;
select * from diabetic_data_raw ;

select count(*) from diabetic_data_raw;

set sql_safe_updates=0;


update diabetic_data_raw
set race=nullif(race,'?'),
	weight=nullif(weight,'?'),
    payer_code=nullif(payer_code,'?'),
    medical_specialty=nullif(medical_specialty,'?'),
    diag_1=nullif(diag_1,'?'),
    diag_2=nullif(diag_2,'?'),
    diag_3=nullif(diag_3,'?');

Alter table diabetic_data_raw modify diag_1 varchar(10);

set sql_safe_updates=1;    

-- Step#1
SELECT 
     round(sum(weight is null)/count(*)*100,1) AS Pct_missing_weight,
     round(sum(payer_code is null)/count(*)*100,1) AS Pct_payer_code,
     round(sum(medical_specialty is null)/count(*)*100,1) AS Pct_medical_specialty
     from diabetic_data_raw;
     
    -- Step#2 
 SElECT 
 patient_nbr,count(*) as encountered_count 
 from diabetic_data_raw 
 group by patient_nbr having count(*)>1
 order by encountered_count desc;
 
 
 
create table diabetic_data_dedup AS
select t.* from diabetic_data_raw as t 
inner join (
select patient_nbr, min(encounter_id) as first_encounter
from diabetic_data_raw group by patient_nbr
)    first_enc
on t.patient_nbr=first_enc.patient_nbr
                   AND
   t.encounter_id=first_enc.first_encounter;



--  STEP#3-- 
Select discharge_disposition_id,count(*)conter_count from diabetic_data_raw
group by discharge_disposition_id order by conter_count desc ;

select * from ids_mapping_raw
where description like '%Expired%' or  description like '%hospice%'or description like '%deceased%';

delete from diabetic_data_dedup where discharge_disposition_id in(11,13,14,19,20,21,26);

--  STEP#4--
select * from ids_mapping_raw;

create table discharge_disposition_map (
discharge_disposition_id int,
discharge_disposition_description varchar(150)
);

create table admission_source_map (
admission_source_id int,
admission_source_description varchar(150)
);

INSERT INTO discharge_disposition_map 
VALUES
(1, 'Discharged to home'),
(2, 'Discharged/transferred to another short term hospital'),
(3, 'Discharged/transferred to SNF'),
(4, 'Discharged/transferred to ICF'),
(5, 'Discharged/transferred to another type of inpatient care institution'),
(6, 'Discharged/transferred to home with home health service'),
(7, 'Left AMA'),
(8, 'Discharged/transferred to home under care of Home IV provider'),
(9, 'Admitted as an inpatient to this hospital'),
(10, 'Neonate discharged to another hospital for neonatal aftercare'),
(11, 'Expired'),
(12, 'Still patient or expected to return for outpatient services'),
(13, 'Hospice / home'),
(14, 'Hospice / medical facility'),
(15, 'Discharged/transferred within this institution to Medicare approved swing bed'),
(16, 'Discharged/transferred/referred another institution for outpatient services'),
(17, 'Discharged/transferred/referred to this institution for outpatient services'),
(18, 'NULL'),
(19, 'Expired at home. Medicaid only, hospice.'),
(20, 'Expired in a medical facility. Medicaid only, hospice.'),
(21, 'Expired, place unknown. Medicaid only, hospice.'),
(22, 'Discharged/transferred to another rehab facility including rehab units of a hospital'),
(23, 'Discharged/transferred to a long term care hospital'),
(24, 'Discharged/transferred to a nursing facility certified under Medicaid but not certified under Medicare'),
(25, 'Not Mapped'),
(26, 'Unknown/Invalid'),
(27, 'Discharged/transferred to a federal health care facility'),
(28, 'Discharged/transferred/referred to a psychiatric hospital or psychiatric distinct part unit of a hospital'),
(29, 'Discharged/transferred to a Critical Access Hospital (CAH)'),
(30, 'Discharged/transferred to another type of health care institution not defined elsewhere');

INSERT INTO admission_source_map 
VALUES
(1, 'Physician Referral'),
(2, 'Clinic Referral'),
(3, 'HMO Referral'),
(4, 'Transfer from a hospital'),
(5, 'Transfer from a Skilled Nursing Facility (SNF)'),
(6, 'Transfer from another health care facility'),
(7, 'Emergency Room'),
(8, 'Court/Law Enforcement'),
(9, 'Not Available'),
(10, 'Transfer from critical access hospital'),
(11, 'Normal Delivery'),
(12, 'Premature Delivery'),
(13, 'Sick Baby'),
(14, 'Extramural Birth'),
(15, 'Not Available'),
(17, 'NULL'),
(18, 'Transfer From Another Home Health Agency'),
(19, 'Readmission to Same Home Health Agency'),
(20, 'Not Mapped'),
(21, 'Unknown/Invalid'),
(22, 'Transfer from hospital inpatient/same facility resulting in a separate claim'),
(23, 'Born inside this hospital'),
(24, 'Born outside this hospital'),
(25, 'Transfer from Ambulatory Surgery Center'),
(26, 'Transfer from Hospice');


select * from admission_source_map ;
select * from discharge_disposition_map  ;

-- STEP 5
select * from diabetic_data_dedup
LIMIT 50;

alter table diabetic_data_dedup add column age_midpoint int;

update diabetic_data_dedup
set age_midpoint= 
CASE
    WHEN age = '[0-10)' THEN 5
    WHEN age = '[10-20)' THEN 15
    WHEN age = '[20-30)' THEN 25
    WHEN age = '[30-40)' THEN 35
    WHEN age = '[40-50)' THEN 45
    WHEN age = '[50-60)' THEN 55
    WHEN age = '[60-70)' THEN 65
    WHEN age = '[70-80)' THEN 75
    WHEN age = '[80-90)' THEN 85
    WHEN age = '[90-100)' THEN 95
END ;

-- EXPLORATORY DATA ANALYSIS 

SELECT readmitted ,
count(*) as total_visits,
round(count(*)/(select count(*) from diabetic_data_dedup) * 100,1) as total_pecentage 
from diabetic_data_dedup
group by readmitted 
order by total_visits desc;


SELECT age,age_midpoint,
count(*) as total_visits,
sum(readmitted ='<30')as readmitted_under_30,
round(sum(readmitted='<30')/count(*) *100,1) as redmission_rate_percentage
from diabetic_data_dedup
group by age,age_midpoint
order by age_midpoint;


SELECT m.description as admission_type ,
count(*) as total_visits,
round(sum(d.readmitted ='<30') / count(*) * 100 ,1) as readmission_rate
from diabetic_data_dedup as d
join ids_mapping_raw as m
on d.admission_type_id=m.admission_type_id
group by m.description
order by readmission_rate desc;

-- ADVANCE TECHNIQUES

WITH patient_risk_base As(
SELECT
    encounter_id,
    patient_nbr,
    age_midpoint,
    time_in_hospital,
    num_medications,
    num_lab_procedures,
    number_diagnoses,
    number_inpatient,
    number_emergency,
    number_outpatient,
    diag_1,
    readmitted,
	case when readmitted='<30' then 1 else 0 end as is_readmitted_30
	from diabetic_data_dedup
	)
    select * from  patient_risk_base
    limit 20; 
    
    
    WITH patient_risk_base As(
SELECT
    encounter_id,
    age_midpoint,
    num_medications,
    readmitted,
    	case when readmitted='<30' then 1 else 0 end as is_readmitted_30
    from diabetic_data_dedup
    )
    SELECT
    encounter_id,
    age_midpoint,
    num_medications,
    RANK() OVER (
    PARTITION BY age_midpoint
    ORDER BY num_medications DESC)
	AS med_rank_age_group
    from patient_risk_base
    order by age_midpoint,med_rank_age_group
    limit 200;
    

    
WITH patient_risk_base As(
SELECT
    encounter_id,
    number_inpatient,
    readmitted,
    	case when readmitted='<30' then 1 else 0 end as is_readmitted_30
    from diabetic_data_dedup
    )
    SELECT
    encounter_id,
    number_inpatient,
    ntile(4) over(order by number_inpatient desc) as risk_quartile
    from patient_risk_base;
    
    SELECT 
     encounter_id,
     num_medications,
     case when num_medications <=10 then 'low'
          when num_medications between 11 and 20 then 'medium'
          else 'high' end as medication_burden_tier,
     case when number_diagnoses <=5 then 'low complexity'
          when number_diagnoses between 6 and 9 then 'medium complexity'
          else 'high complexity' end as _diagnoses_complexity_tier
          from diabetic_data_dedup; 
-- SECTION 3          
with diag_categorized As(
select 
encounter_id,
readmitted,
case 
when diag_1  like '250%' then 'Diabeties'
when cast(left(diag_1,3) as unsigned) between 390 and 459 then 'CIRCULATOERY'
when cast(left(diag_1,3) as unsigned) between 460 and 519 then 'RESPIRATRORY'
when cast(left(diag_1,3) as unsigned) between 520 and 579 then 'DIGESTIVE'
when cast(left(diag_1,3) as unsigned) between 580 and 629 then 'GENETOOURINARY'
when cast(left(diag_1,3) as unsigned) between 630 and 999 then 'INJURY'
ELSE 'other'
end as diagnostic_category,
CASE 
WHEN  readmitted ='<30' then 1 else 0 end as is_readmitted_30
    from diabetic_data_dedup
    where diag_1 is not null
    )
select  diagnostic_category ,       
count(*) as total_encoutners,
round(avg(is_readmitted_30)  * 100 ,1) as admission_rate_pct
    from  diag_categorized 
    group by diagnostic_category
    having avg(is_readmitted_30) > (select avg(is_readmitted_30) from diag_categorized)
    order by admission_rate_pct desc;

-- SECTION 4	

select `change`,
count(*) as total_encounter,
round(sum(readmitted ='<30') / count(*) *100,1) as admission_rate_pct
from diabetic_data_dedup
group by `change`;




SELECt m.discharge_disposition_description AS discharge_disposition,
    COUNT(*) AS total_encounters,
    ROUND(SUM(d.readmitted = '<30') / COUNT(*) * 100,1) AS readmission_rate_pct
FROM diabetic_data_dedup AS d
JOIN discharge_disposition_map AS m
    ON d.discharge_disposition_id = m.discharge_disposition_id
GROUP BY m.discharge_disposition_description
HAVING COUNT(*) > 100
ORDER BY readmission_rate_pct DESC
LIMIT 10;

SELECT 
 A1Cresult,count(*) as total_encounters,
  ROUND(SUM(readmitted = '<30') / COUNT(*) * 100,1) AS readmission_rate_pct
  from diabetic_data_dedup
  group by A1Cresult;





      
    
    
    