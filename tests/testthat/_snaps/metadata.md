# print.harbour_metadata renders the base summary

    Code
      print(hb_example_metadata())
    Message
      
      -- <harbour_metadata> ----------------------------------------------------------
      * base : "harbouR demo base"
      * tables : 2
      
      - Samples (7 cols, 1 views)
      - Patients (4 cols, 1 views)

# summary.harbour_metadata renders the column breakdown

    Code
      summary(hb_example_metadata())
    Output
      # A tibble: 11 x 3
         table    column        type           
         <chr>    <chr>         <chr>          
       1 Samples  Name          text           
       2 Samples  Concentration number         
       3 Samples  Status        single-select  
       4 Samples  Tags          multiple-select
       5 Samples  Collected     date           
       6 Samples  Collaborators collaborator   
       7 Samples  Reports       file           
       8 Patients Patient ID    text           
       9 Patients Age           number         
      10 Patients Consented     checkbox       
      11 Patients Last visit    date           

