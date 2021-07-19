--Q0
GET /ontime/_search?pretty 
{
  "size": 0,
  "query": {
    "constant_score": {
      "filter": {
        "match_all": {
          "boost": 1
        }
      },
      "boost": 1
    }
  },
  "_source": false,
  "aggregations": {
    "by_year_month": {
      "terms": {
        "script": {
          "lang": "painless",
          "source": "(doc['Year'].size() > 0 ? doc['Year'].value* 100 : 0) + (doc['Month'].size() > 0 ? doc['Month'].value : 0)"
        }
      }
    },
    "avg_monthly": {
      "avg_bucket": {
        "buckets_path": "by_year_month._count"
      }
    }
  }
}

--Q1
POST /_sql?format=txt&pretty
{
	"query": "SELECT DayOfWeek, count(*) AS c FROM ontime WHERE Year>=2000 AND Year<=2008 GROUP BY DayOfWeek ORDER BY c DESC"
}

--Q2
POST /_sql?format=txt&pretty
{
	"query": "SELECT DayOfWeek, count(*) AS c FROM ontime WHERE DepDelay>10 AND Year>=2000 AND Year<=2008 GROUP BY DayOfWeek ORDER BY c DESC"
}

--Q3
POST
{
	"query": "SELECT Origin, count(*) AS c FROM ontime WHERE DepDelay>10 AND Year>=2000 AND Year<=2008 GROUP BY Origin ORDER BY c DESC LIMIT 10"
}

--Q4
POST /_sql?format=txt&pretty
{
	"query": "SELECT Carrier, count(*) FROM ontime WHERE DepDelay>10 AND Year=2007 GROUP BY Carrier ORDER BY count(*) DESC"
}

--Q5
GET /ontime/_search?pretty
{
  "size": 0,
  "query": {
    "constant_score": {
      "filter": {
        "term": {
          "Year": {
            "value": 2007,
            "boost": 1
          }
        }
      },
      "boost": 1
    }
  },
  "_source": false,
  "aggregations": {
    "by_carrier": {
      "terms": {
        "field": "Carrier",
        "order": [
          {
            "c3": "asc"
          },
          {
            "_key": "asc"
          }
        ]
      },
      "aggregations": {
        "c3": {
          "avg": {
            "script": {
              "source": "doc['DepDelay'].value > 10 ? 100.0 : 0.0 ",
              "lang": "painless"
            }
          }
        }
      }
    }
  }
}

--Q6
GET /ontime/_search?pretty {
{
  "size": 0,
  "query": {
    "constant_score": {
      "filter": {
        "range": {
          "Year": {
            "from": 2000,
            "to": 2008,
            "include_lower": true,
            "include_upper": true,
            "boost": 1
          }
        }
      },
      "boost": 1
    }
  },
  "_source": false,
  "aggregations": {
    "by_carrier": {
      "terms": {
        "field": "Carrier",
        "order": [
          {
            "c3": "asc"
          },
          {
            "_key": "asc"
          }
        ]
      },
      "aggregations": {
        "c3": {
          "avg": {
            "script": {
              "source": "doc['DepDelay'].value > 10 ? 100.0 : 0.0",
              "lang": "painless"
            }
          }
        }
      }
    }
  }
}

--Q7
GET /ontime/_search?pretty {
{
  "size": 0,
  "_source": false,
  "stored_fields": "_none_",
  "aggregations": {
    "groupby": {
      "terms": {
        "field": "Year",
        "order": [
          {
            "_key": "asc"
          }
        ]
      },
      "aggregations": {
        "45915a29": {
          "avg": {
            "script": {
              "source": "doc['DepDelay'].value > 10 ? 100.0 : 0.0",
              "lang": "painless"
            }
          }
        }
      }
    }
  }
}

--Q8
POST /_sql?format=txt&pretty {
	"query": "SELECT DestCityName, count(distinct OriginCityName) AS u FROM ontime WHERE Year >= 2000 and Year <= 2010 GROUP BY DestCityName ORDER BY u DESC LIMIT 10"
}

--Q9
POST /_sql?format=txt&pretty {
	"query": "SELECT Year, count(*) AS c1 FROM ontime GROUP BY Year" 
}

--Q10
GET /ontime/_search?pretty
{
  "size": 0,
  "query": {
    "constant_score": {
      "filter": {
        "bool": {
          "must": [
            {
              "range": {
                "FlightDate": {
                  "from": null,
                  "to": "2010-01-01",
                  "include_lower": true,
                  "include_upper": false,
                  "boost": 1
                }
              }
            }
          ],
          "must_not": [
            {
              "term": {
                "DestState": {
                  "value": "AK",
                  "boost": 1
                }
              }
            },
            {
              "term": {
                "DestState": {
                  "value": "HI",
                  "boost": 1
                }
              }
            },
            {
              "term": {
                "DestState": {
                  "value": "PR",
                  "boost": 1
                }
              }
            },
            {
              "term": {
                "DestState": {
                  "value": "VI",
                  "boost": 1
                }
              }
            },
            {
              "term": {
                "DayOfWeek": {
                  "value": 6,
                  "boost": 1
                }
              }
            },
            {
              "term": {
                "DayOfWeek": {
                  "value": 7,
                  "boost": 1
                }
              }
            },
            {
              "term": {
                "OriginState": {
                  "value": "AK",
                  "boost": 1
                }
              }
            },
            {
              "term": {
                "OriginState": {
                  "value": "PR",
                  "boost": 1
                }
              }
            },
            {
              "term": {
                "OriginState": {
                  "value": "HI",
                  "boost": 1
                }
              }
            },
            {
              "term": {
                "OriginState": {
                  "value": "VI",
                  "boost": 1
                }
              }
            }
          ],
          "adjust_pure_negative": true,
          "boost": 1
        }
      },
	  "boost": 1
    }
  },
  "_source": false,
  "aggregations": {
    "by_carrier": {
      "terms": {
        "field": "Carrier",
        "order": [
          {
            "_count": "desc"
          },
          {
            "_key": "asc"
          }
        ]
      },
      "aggregations": {
        "minYear": {
          "min": {
            "field": "Year"
          }
        },
        "maxYear": {
          "max": {
            "field": "Year"
          }
        },
        "flights_delayed": {
          "sum": {
            "script": {
              "source": "doc['ArrDelayMinutes'].value > 30 ? 1 : 0",
              "lang": "painless"
            }
          }
        },
        "rate": {
          "bucket_script": {
            "buckets_path": {
              "_value0": "flights_delayed",
              "_value1": "_count"
            },
            "script": {
              "source": "1.0 * params._value0 / params._value1",
              "lang": "painless"
            }
          }
        },
        "having_cnt": {
          "bucket_selector": {
            "buckets_path": {
              "_value0": "_count"
            },
            "script": {
              "source": "params._value0 > 100000",
              "lang": "painless"
            }
          }
        },
        "having_year": {
          "bucket_selector": {
            "buckets_path": {
              "_value0": "maxYear"
            },
            "script": {
              "source": "params._value0 > 1990",
              "lang": "painless"
            }
          }
        },
        "order_by_rate": {
          "bucket_sort": {
            "sort": [
              {
                "rate": {
                  "order": "desc"
                }
              }
            ],
            "from": 0,
            "size": 1000
          }
        }
      }
    }
  }
}

--Q11
{
  "size": 0,
  "query": {
    "constant_score": {
      "filter": {
        "term": {
          "DepDel15": {
            "value": 1,
            "boost": 1
          }
        }
      },
      "boost": 1
    }
  },
  "_source": false,
  "aggregations": {
    "by_year_month": {
      "terms": {
        "script": {
          "source": "doc['Year'].value * 100 + doc['Month'].value",
          "lang": "painless"
        }
      }
    },
    "avg_monthly": {
      "avg_bucket": {
        "buckets_path": "by_year_month._count"
      }
    }
  }
}

--Q12
GET /ontime/_search?pretty 
{
  "size": 0,
  "query": {
    "constant_score": {
      "filter": {
        "match_all": {
          "boost": 1
        }
      },
      "boost": 1
    }
  },
  "_source": false,
  "aggregations": {
    "by_year_month": {
      "terms": {
        "script": {
          "source": "(doc['Year'].size() > 0 ? doc['Year'].value * 100 : 0) + (doc['Month'].size() > 0 ? doc['Month'].value : 0)",
          "lang": "painless"
        }
      }
    },
    "avg_monthly": {
      "avg_bucket": {
        "buckets_path": "by_year_month._count"
      }
    }
  }
}
 
--Q13
POST /_sql?format=txt&pretty
{
	"query": "SELECT DestCityName, count(distinct OriginCityName) AS u FROM ontime GROUP BY DestCityName ORDER BY u DESC LIMIT 1 0"
}

--Q14
POST /_sql?format=txt&pretty
{
	"query": "SELECT OriginCityName, DestCityName, count(*) AS c FROM ontime GROUP BY OriginCityName, DestCityName ORDER BY c DESC LIMIT 10"
}

--Q15
POST /_sql?format=txt&pretty
{
	"query": "SELECT OriginCityName, count(*) AS c FROM ontime GROUP BY OriginCityName ORDER BY c DESC LIMIT 10"
}

