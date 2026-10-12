from pathlib import Path
import pandas as pd

DATA_FILE = Path(__file__).resolve().parent / 'flood dataset.xlsx'
SHEET_NAME = 'Sheet5'

df = pd.read_excel(DATA_FILE, sheet_name=SHEET_NAME)

print('=' * 60)
print('FLOODRESQ-AI DATASET INSPECTION')
print('=' * 60)
print('\nShape:', df.shape)
print('\nColumns:')
for column in df.columns:
    print('-', column)
print('\nData types:')
print(df.dtypes)
print('\nMissing values:')
print(df.isnull().sum())
print('\nTarget distribution:')
print(df['flood'].value_counts().sort_index())
print('\nFirst 5 rows:')
print(df.head())
