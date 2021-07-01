# CorrelationDataImporter

A collection of classes to import data from various battery testing facilities
and convert them to a standard form.

Classes:

rateTestDataImporter        Abstract parent class
lancasterRateTestData       Concrete child class to import data from the Lancaster BATLAB facility
warwickRateTestData         Concrete child class to import data from the Warwick facility
imperialRateTestData        Concrete child class to import data from the Imperial facility
oxfordRateTestData          Concrete child class to import data from the Oxford facility
birminghamRateTestData      Concrete child class to import data from the Birmingham facility  
states                      Enumeration for cell states in Birmingham data. Necessary for identifying
                            the discharge events.