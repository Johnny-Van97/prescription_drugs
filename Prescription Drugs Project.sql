--There will be some duplicate values in the drug table 

SELECT *
FROM drug
WHERE drug_name LIKE 'POTASSIUM CHLORIDE'
ORDER BY drug_name;

--1.
    --a. Which prescriber had the highest total number of claims (totaled over all drugs)? Report the npi and the total number of claims.
	--INCORRECT, CORRECTED

SELECT SUM(total_claim_count) AS total_claims, npi
FROM prescriber
	INNER JOIN prescription USING (npi)
GROUP BY npi
ORDER BY total_claims DESC; 

    --b. Repeat the above, but this time report the nppes_provider_first_name, nppes_provider_last_org_name,  specialty_description, and the total number of claims.
	--CORRECT

SELECT prescriber.nppes_provider_first_name, prescriber.nppes_provider_last_org_name, prescriber.specialty_description, total_claim_count
FROM prescriber
	INNER JOIN prescription USING (npi)
ORDER BY total_claim_count DESC;

--2.
    --a. Which specialty had the most total number of claims (totaled over all drugs)?
	--INCORRECT, CORRECTED

SELECT prescriber.specialty_description, SUM(total_claim_count) AS total_claim_count
FROM prescriber
	INNER JOIN prescription ON prescriber.npi = prescription.npi
GROUP BY prescriber.specialty_description
ORDER BY total_claim_count DESC;


    --b. Which specialty had the most total number of claims for opioids?
	--CORRECT

SELECT DISTINCT prescriber.specialty_description, SUM(total_claim_count) AS total_claim_count, drug.opioid_drug_flag
FROM prescriber
	INNER JOIN prescription ON prescriber.npi = prescription.npi
	INNER JOIN drug ON prescription.drug_name = drug.drug_name
WHERE drug.opioid_drug_flag = 'Y' 
GROUP BY prescriber.specialty_description, drug.opioid_drug_flag
ORDER BY total_claim_count DESC;

    --c. **Challenge Question:** Are there any specialties that appear in the prescriber table that have no associated prescriptions in the prescription table?

SELECT specialty_description, SUM(total_claim_count) AS claims
FROM prescriber
	LEFT JOIN prescription USING (npi)
GROUP BY specialty_description
HAVING SUM(total_claim_count) IS NULL
ORDER BY claims

    --d. **Difficult Bonus:** *Do not attempt until you have solved all other problems!* For each specialty, 
	--report the percentage of total claims by that specialty which are for opioids. Which specialties have a high percentage of opioids?

SELECT specialty_description,
ROUND(SUM(CASE WHEN opioid_drug_flag = 'Y' THEN total_claim_count END)/SUM(total_claim_count) * 100, 2) AS opioids
FROM prescriber
	INNER JOIN prescription USING (npi)
	INNER JOIN (SELECT DISTINCT drug_name, opioid_drug_flag
				FROM drug) AS drug USING (drug_name)
GROUP BY specialty_description
ORDER BY opioids DESC NULLS LAST;

--3.
    --a. Which drug (generic_name) had the highest total drug cost?
--CORRECT ASIDE FOR NOT ACCOUNTING FOR DUPLICATES!

SELECT DISTINCT generic_name, SUM(total_drug_cost)::money AS drug_cost_total
FROM drug
	INNER JOIN prescription USING (drug_name)
GROUP BY generic_name
ORDER BY drug_cost_total DESC;


    --b. Which drug (generic_name) has the hightest total cost per day? **Bonus: Round your cost per day column to 2 decimal places. Google ROUND to see how this works.
	--CORRECT

SELECT DISTINCT generic_name, ROUND(SUM(total_drug_cost) / SUM(total_day_supply),2)::money AS cost_per_day
FROM drug
	INNER JOIN prescription ON drug.drug_name = prescription.drug_name
GROUP BY generic_name
ORDER BY cost_per_day DESC;

--4.
    --a. For each drug in the drug table, return the drug name and then a column named 'drug_type' which says 'opioid'... 
	--...for drugs which have opioid_drug_flag = 'Y', says 'antibiotic' for those drugs which have antibiotic_drug_flag = 'Y', and says 'neither' for all other drugs.
	--**Hint:** You may want to use a CASE expression for this. See https://www.postgresqltutorial.com/postgresql-tutorial/postgresql-case/

SELECT drug_name,
	CASE WHEN opioid_drug_flag = 'Y' THEN 'opioid'
         WHEN antibiotic_drug_flag = 'Y' THEN 'antibiotic'
	ELSE 'neither' END AS drug_type
FROM (SELECT DISTINCT drug_name, opioid_drug_flag, antibiotic_drug_flag FROM drug) AS drug;

    --b. Building off of the query you wrote for part a, determine whether more was spent (total_drug_cost) on opioids or on antibiotics. 
	--Hint: Format the total costs as MONEY for easier comparision.
-- CORRECT BUT NEEDED HELP
WITH drug_type AS(
	SELECT DISTINCT drug_name,
	CASE WHEN opioid_drug_flag = 'Y' THEN 'opioid'
         WHEN antibiotic_drug_flag = 'Y' THEN 'antibiotic'
		 ELSE 'neither' END AS drug_type
	FROM drug)
SELECT drug_type, SUM(total_drug_cost)::money
FROM drug_type
INNER JOIN prescription USING (drug_name)
GROUP BY drug_type;	

--5.
    --a. How many CBSAs are in Tennessee? **Warning:** The cbsa table contains information for all states, not just Tennessee.
-- INCORRECT, CORRECTED
SELECT COUNT(DISTINCT cbsa)
FROM cbsa
	INNER JOIN fips_county USING (fipscounty)
WHERE state = 'TN';

    --b. Which cbsa has the largest combined population? Which has the smallest? Report the CBSA name and total population.
--INCORRECT, NOT CORRECTED
SELECT cbsaname, SUM(population) AS total_pop
FROM cbsa
INNER JOIN population USING (fipscounty)
GROUP BY cbsaname
ORDER BY total_pop DESC NULLS LAST;

    --c. What is the largest (in terms of population) county which is not included in a CBSA? Report the county name and population.

SELECT *
FROM population
	LEFT JOIN cbsa ON population.fipscounty = cbsa.fipscounty
	LEFT JOIN fips_county ON population.fipscounty = fips_county.fipscounty
WHERE cbsa IS NULL
ORDER BY population DESC
LIMIT 1;



--6.
    --a. Find all rows in the prescription table where total_claims is at least 3000. Report the drug_name and the total_claim_count.
--CORRECT
SELECT drug_name, total_claim_count
FROM prescription
WHERE total_claim_count >= 3000;

    --b. For each instance that you found in part a, add a column that indicates whether the drug is an opioid.
--CORRECT
SELECT drug.drug_name, total_claim_count, opioid_drug_flag
FROM drug
INNER JOIN prescription USING(drug_name)
WHERE total_claim_count >= 3000;

    --c. Add another column to your answer from the previous part which gives the prescriber first and last name associated with each row.
	--CORRECT
SELECT drug.drug_name, total_claim_count, opioid_drug_flag, nppes_provider_last_org_name, nppes_provider_first_name
FROM drug
INNER JOIN prescription USING(drug_name)
INNER JOIN prescriber USING (npi)
WHERE total_claim_count >= 3000;
	

--7. The goal of this exercise is to generate a full list of all pain management specialists in Nashville and the number of claims they had for each opioid. 
    --**Hint:** The results from all 3 parts will have 637 rows.

    --a. First, create a list of all npi/drug_name combinations for pain management specialists (specialty_description = 'Pain Management) 
	--in the city of Nashville (nppes_provider_city = 'NASHVILLE'), where the drug is an opioid (opiod_drug_flag = 'Y'). 
	--**Warning:** Double-check your query before running it. You will only need to use the prescriber and drug tables since you don't need the claims numbers yet.
--CORRECT
SELECT npi, drug.drug_name
FROM drug
	CROSS JOIN prescriber
WHERE nppes_provider_city = 'NASHVILLE' 
	AND specialty_description = 'Pain Management' 
	AND opioid_drug_flag = 'Y';


    --b. Next, report the number of claims per drug per prescriber. Be sure to include all combinations, whether or not the prescriber had any claims. 
	--You should report the npi, the drug name, and the number of claims (total_claim_count).
    --c. Finally, if you have not done so already, fill in any missing values for total_claim_count with 0. Hint - Google the COALESCE function.
--CORRECT
SELECT npi, drug.drug_name, COALESCE (total_claim_count,'0') AS total_claim_count
FROM drug
	CROSS JOIN prescriber
	LEFT JOIN prescription USING (npi, drug_name)
WHERE nppes_provider_city = 'NASHVILLE' 
	AND specialty_description = 'Pain Management' 
	AND opioid_drug_flag = 'Y'
ORDER BY total_claim_count DESC

